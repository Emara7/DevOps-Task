#!/usr/bin/env bash
set -euo pipefail

# AWS Cost Cleanup Script
# Default behavior is DRY-RUN (no destructive calls). Use --execute to actually delete.
# Supports multi-region cleanup of common billable resources.
# Requires: awscli v2, jq

SCRIPT_NAME="$(basename "$0")"

DRY_RUN=1
EXECUTE=0
PROFILE=""
REGIONS=""
INCLUDE_S3=0
INCLUDE_SNAPSHOTS=0     # EBS + RDS snapshots
INCLUDE_ROUTE53=0
INCLUDE_CLOUDFRONT=0
INCLUDE_KMS=0
DELETE_VPCS=0           # Not recommended; VPCs themselves don't cost
ONLY_SERVICES=""       # comma-separated subset, e.g. ec2,rds,eks
SKIP_SERVICES=""       # comma-separated blacklist
NO_FINAL_SNAPSHOT=1     # RDS/Redshift: skip final snapshot (avoids extra cost)
ASSUME_ROLE_ARN=""
SESSION_NAME="aws-cleanup-session"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

usage() {
  cat <<EOF
${SCRIPT_NAME} - Clean up AWS billable resources safely (DRY-RUN by default)

Usage:
  ${SCRIPT_NAME} [--execute] [--profile NAME] [--regions r1,r2] [--assume-role ARN]
                 [--include-s3] [--include-snapshots] [--include-route53] [--include-cloudfront] [--include-kms]
                 [--only-services list] [--skip-services list] [--delete-vpcs]
                 [--no-final-snapshot=false] [--session-name NAME]

Flags:
  --execute                 Perform deletions (default is dry-run)
  --profile NAME            AWS CLI profile to use
  --regions r1,r2           Limit to specific regions (comma-separated). Default: all available regions
  --assume-role ARN         Assume this role before actions (uses STS)
  --session-name NAME       Session name when assuming role (default: aws-cleanup-session)
  --include-s3              Delete S3 buckets (empties then removes)
  --include-snapshots       Delete EBS and RDS snapshots you own
  --include-route53         Delete Route53 hosted zones (public and private)
  --include-cloudfront      Delete CloudFront distributions (global)
  --include-kms             Schedule deletion of KMS keys (7 day window)
  --only-services list      Only process these services (csv). Known: ec2,elbv2,elb,ebs,eip,nat,rds,eks,ecs,ecr,opensearch,elasticache,redshift,s3,route53,cloudfront,dynamodb,secrets,kms,vpcendpoints
  --skip-services list      Skip these services (csv)
  --delete-vpcs             Attempt to delete empty non-default VPCs (not required for cost)
  --no-final-snapshot=false Keep a final snapshot for RDS/Redshift (default: no final snapshot)
  -h, --help                Show this help

Environment:
  Uses standard AWS_* env variables or --profile. For temporary creds, export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN.

Safe defaults:
  - Dry-run by default
  - S3, Route53, CloudFront, KMS, snapshots require explicit --include-* or flags
  - Does not delete VPCs unless --delete-vpcs given

Examples:
  ${SCRIPT_NAME}                                # Dry-run across all regions
  ${SCRIPT_NAME} --execute --regions us-east-1  # Real delete in us-east-1 only
  ${SCRIPT_NAME} --include-s3 --execute         # Also delete S3 buckets
  ${SCRIPT_NAME} --only-services ec2,rds --execute
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH" >&2
    exit 1
  fi
}

contains_csv() {
  local list="$1"; local item="$2"
  [[ ",$list," == *",${item},"* ]]
}

should_run_service() {
  local svc="$1"
  if [[ -n "$ONLY_SERVICES" ]]; then
    contains_csv "$ONLY_SERVICES" "$svc" || return 1
  fi
  if [[ -n "$SKIP_SERVICES" ]]; then
    contains_csv "$SKIP_SERVICES" "$svc" && return 1
  fi
  return 0
}

confirm_or_echo() {
  local action_desc="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY-RUN: ${action_desc}"
  else
    log "EXECUTE: ${action_desc}"
  fi
}

aws_exec() {
  # Wrapper to inject profile/region and handle dry-run echo
  local region="$1"; shift
  local args=("$@")
  if [[ -n "$PROFILE" ]]; then args=("--profile" "$PROFILE" "${args[@]}"); fi
  if [[ -n "$region" ]]; then args=("--region" "$region" "${args[@]}"); fi
  aws "${args[@]}"
}

assume_role_if_needed() {
  if [[ -n "$ASSUME_ROLE_ARN" ]]; then
    require_cmd aws
    require_cmd jq
    log "Assuming role: $ASSUME_ROLE_ARN"
    local creds
    creds=$(aws sts assume-role --role-arn "$ASSUME_ROLE_ARN" --role-session-name "$SESSION_NAME" --output json)
    export AWS_ACCESS_KEY_ID="$(jq -r '.Credentials.AccessKeyId' <<<"$creds")"
    export AWS_SECRET_ACCESS_KEY="$(jq -r '.Credentials.SecretAccessKey' <<<"$creds")"
    export AWS_SESSION_TOKEN="$(jq -r '.Credentials.SessionToken' <<<"$creds")"
    log "Assumed role successfully."
  fi
}

get_regions() {
  if [[ -n "$REGIONS" ]]; then
    tr ',' '\n' <<< "$REGIONS"
  else
    aws ec2 describe-regions \
      ${PROFILE:+--profile "$PROFILE"} \
      --all-regions --output json \
      | jq -r '.Regions[].RegionName' | sort
  fi
}

# ------------- Service handlers -------------

cleanup_ec2_instances() {
  local region="$1"
  should_run_service ec2 || return 0
  local ids
  ids=$(aws_exec "$region" ec2 describe-instances \
      --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].InstanceId' --output text)
  if [[ -n "$ids" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Terminate EC2 instances in $region: $ids"
    else
      aws_exec "$region" ec2 terminate-instances --instance-ids $ids >/dev/null
      log "Terminated EC2 instances in $region: $ids"
    fi
  fi
}

cleanup_elbv2() {
  local region="$1"
  should_run_service elbv2 || return 0
  local arns
  arns=$(aws_exec "$region" elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text || true)
  if [[ -n "$arns" ]]; then
    for arn in $arns; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete ELBv2 load balancer in $region: $arn"
      else
        aws_exec "$region" elbv2 delete-load-balancer --load-balancer-arn "$arn" >/dev/null || true
      fi
    done
  fi
  # Target groups
  local tgs
  tgs=$(aws_exec "$region" elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output text || true)
  if [[ -n "$tgs" ]]; then
    for tg in $tgs; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete ELBv2 target group in $region: $tg"
      else
        aws_exec "$region" elbv2 delete-target-group --target-group-arn "$tg" >/dev/null || true
      fi
    done
  fi
}

cleanup_elb_classic() {
  local region="$1"
  should_run_service elb || return 0
  local names
  names=$(aws_exec "$region" elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text || true)
  if [[ -n "$names" ]]; then
    for name in $names; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete classic ELB in $region: $name"
      else
        aws_exec "$region" elb delete-load-balancer --load-balancer-name "$name" >/dev/null || true
      fi
    done
  fi
}

cleanup_eips() {
  local region="$1"
  should_run_service eip || return 0
  local allocs
  allocs=$(aws_exec "$region" ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId' --output text || true)
  if [[ -n "$allocs" ]]; then
    for alloc in $allocs; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Release Elastic IP in $region: $alloc"
      else
        aws_exec "$region" ec2 release-address --allocation-id "$alloc" >/dev/null || true
      fi
    done
  fi
}

cleanup_ebs_volumes() {
  local region="$1"
  should_run_service ebs || return 0
  local vols
  vols=$(aws_exec "$region" ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text || true)
  if [[ -n "$vols" ]]; then
    for vid in $vols; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete EBS volume in $region: $vid"
      else
        aws_exec "$region" ec2 delete-volume --volume-id "$vid" >/dev/null || true
      fi
    done
  fi
}

cleanup_ebs_snapshots() {
  local region="$1"
  should_run_service ebs || return 0
  [[ $INCLUDE_SNAPSHOTS -eq 1 ]] || return 0
  local snaps
  snaps=$(aws_exec "$region" ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId' --output text || true)
  if [[ -n "$snaps" ]]; then
    for sid in $snaps; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete EBS snapshot in $region: $sid"
      else
        aws_exec "$region" ec2 delete-snapshot --snapshot-id "$sid" >/dev/null || true
      fi
    done
  fi
}

cleanup_nat_gateways() {
  local region="$1"
  should_run_service nat || return 0
  local nat_ids
  nat_ids=$(aws_exec "$region" ec2 describe-nat-gateways --filter Name=state,Values=pending,failed,available --query 'NatGateways[].NatGatewayId' --output text || true)
  if [[ -n "$nat_ids" ]]; then
    for nid in $nat_ids; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete NAT Gateway in $region: $nid"
      else
        aws_exec "$region" ec2 delete-nat-gateway --nat-gateway-id "$nid" >/dev/null || true
      fi
    done
  fi
}

cleanup_vpc_endpoints() {
  local region="$1"
  should_run_service vpcendpoints || return 0
  local eps
  eps=$(aws_exec "$region" ec2 describe-vpc-endpoints --query 'VpcEndpoints[].VpcEndpointId' --output text || true)
  if [[ -n "$eps" ]]; then
    for eid in $eps; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete VPC endpoint in $region: $eid"
      else
        aws_exec "$region" ec2 delete-vpc-endpoints --vpc-endpoint-ids "$eid" >/dev/null || true
      fi
    done
  fi
}

cleanup_rds() {
  local region="$1"
  should_run_service rds || return 0
  # Instances
  local instances
  instances=$(aws_exec "$region" rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text || true)
  if [[ -n "$instances" ]]; then
    for id in $instances; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete RDS instance in $region: $id"
      else
        if [[ $NO_FINAL_SNAPSHOT -eq 1 ]]; then
          aws_exec "$region" rds delete-db-instance --db-instance-identifier "$id" --skip-final-backup >/dev/null || true
        else
          aws_exec "$region" rds delete-db-instance --db-instance-identifier "$id" --final-db-snapshot-identifier "final-$id-$(date +%s)" >/dev/null || true
        fi
      fi
    done
  fi
  # Clusters (Aurora)
  local clusters
  clusters=$(aws_exec "$region" rds describe-db-clusters --query 'DBClusters[].DBClusterIdentifier' --output text || true)
  if [[ -n "$clusters" ]]; then
    for cid in $clusters; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete RDS cluster in $region: $cid"
      else
        if [[ $NO_FINAL_SNAPSHOT -eq 1 ]]; then
          aws_exec "$region" rds delete-db-cluster --db-cluster-identifier "$cid" --skip-final-snapshot >/dev/null || true
        else
          aws_exec "$region" rds delete-db-cluster --db-cluster-identifier "$cid" --final-db-snapshot-identifier "final-$cid-$(date +%s)" >/dev/null || true
        fi
      fi
    done
  fi
  # Snapshots
  if [[ $INCLUDE_SNAPSHOTS -eq 1 ]]; then
    local rsnaps
    rsnaps=$(aws_exec "$region" rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[].DBSnapshotIdentifier' --output text || true)
    if [[ -n "$rsnaps" ]]; then
      for sid in $rsnaps; do
        if [[ $DRY_RUN -eq 1 ]]; then
          confirm_or_echo "Delete RDS snapshot in $region: $sid"
        else
          aws_exec "$region" rds delete-db-snapshot --db-snapshot-identifier "$sid" >/dev/null || true
        fi
      done
    fi
  fi
}

cleanup_eks() {
  local region="$1"
  should_run_service eks || return 0
  local clusters
  clusters=$(aws_exec "$region" eks list-clusters --query 'clusters[]' --output text || true)
  for c in $clusters; do
    # delete nodegroups
    local ngs
    ngs=$(aws_exec "$region" eks list-nodegroups --cluster-name "$c" --query 'nodegroups[]' --output text || true)
    for ng in $ngs; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete EKS nodegroup in $region: $c/$ng"
      else
        aws_exec "$region" eks delete-nodegroup --cluster-name "$c" --nodegroup-name "$ng" >/dev/null || true
      fi
    done
    # delete fargate profiles
    local fps
    fps=$(aws_exec "$region" eks list-fargate-profiles --cluster-name "$c" --query 'fargateProfileNames[]' --output text || true)
    for fp in $fps; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete EKS fargate profile in $region: $c/$fp"
      else
        aws_exec "$region" eks delete-fargate-profile --cluster-name "$c" --fargate-profile-name "$fp" >/dev/null || true
      fi
    done
    # delete cluster
    if [[ -n "$c" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete EKS cluster in $region: $c"
      else
        aws_exec "$region" eks delete-cluster --name "$c" >/dev/null || true
      fi
    fi
  done
}

cleanup_ecs() {
  local region="$1"
  should_run_service ecs || return 0
  local clusters
  clusters=$(aws_exec "$region" ecs list-clusters --query 'clusterArns[]' --output text || true)
  for carrn in $clusters; do
    local services
    services=$(aws_exec "$region" ecs list-services --cluster "$carrn" --query 'serviceArns[]' --output text || true)
    for s in $services; do
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete ECS service in $region: $s"
      else
        aws_exec "$region" ecs update-service --cluster "$carrn" --service "$s" --desired-count 0 >/dev/null || true
        aws_exec "$region" ecs delete-service --cluster "$carrn" --service "$s" --force >/dev/null || true
      fi
    done
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete ECS cluster in $region: $carrn"
    else
      aws_exec "$region" ecs delete-cluster --cluster "$carrn" >/dev/null || true
    fi
  done
}

cleanup_ecr() {
  local region="$1"
  should_run_service ecr || return 0
  local repos
  repos=$(aws_exec "$region" ecr describe-repositories --query 'repositories[].repositoryName' --output text || true)
  for r in $repos; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete ECR repository in $region: $r"
    else
      aws_exec "$region" ecr delete-repository --repository-name "$r" --force >/dev/null || true
    fi
  done
}

cleanup_opensearch() {
  local region="$1"
  should_run_service opensearch || return 0
  local names
  names=$(aws_exec "$region" opensearch list-domain-names --query 'DomainNames[].DomainName' --output text || true)
  for n in $names; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete OpenSearch domain in $region: $n"
    else
      aws_exec "$region" opensearch delete-domain --domain-name "$n" >/dev/null || true
    fi
  done
}

cleanup_elasticache() {
  local region="$1"
  should_run_service elasticache || return 0
  local rgs
  rgs=$(aws_exec "$region" elasticache describe-replication-groups --query 'ReplicationGroups[].ReplicationGroupId' --output text || true)
  for rg in $rgs; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete ElastiCache replication group in $region: $rg"
    else
      aws_exec "$region" elasticache delete-replication-group --replication-group-id "$rg" --retain-primary-cluster false >/dev/null || true
    fi
  done
  local clusters
  clusters=$(aws_exec "$region" elasticache describe-cache-clusters --show-cache-node-info --query 'CacheClusters[].CacheClusterId' --output text || true)
  for c in $clusters; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete ElastiCache cluster in $region: $c"
    else
      aws_exec "$region" elasticache delete-cache-cluster --cache-cluster-id "$c" >/dev/null || true
    fi
  done
}

cleanup_redshift() {
  local region="$1"
  should_run_service redshift || return 0
  local clusters
  clusters=$(aws_exec "$region" redshift describe-clusters --query 'Clusters[].ClusterIdentifier' --output text || true)
  for c in $clusters; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete Redshift cluster in $region: $c"
    else
      if [[ $NO_FINAL_SNAPSHOT -eq 1 ]]; then
        aws_exec "$region" redshift delete-cluster --cluster-identifier "$c" --skip-final-cluster-snapshot >/dev/null || true
      else
        aws_exec "$region" redshift delete-cluster --cluster-identifier "$c" --final-cluster-snapshot-identifier "final-$c-$(date +%s)" >/dev/null || true
      fi
    fi
  done
}

cleanup_dynamodb() {
  local region="$1"
  should_run_service dynamodb || return 0
  local tables
  tables=$(aws_exec "$region" dynamodb list-tables --query 'TableNames[]' --output text || true)
  for t in $tables; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete DynamoDB table in $region: $t"
    else
      aws_exec "$region" dynamodb delete-table --table-name "$t" >/dev/null || true
    fi
  done
}

cleanup_secrets() {
  local region="$1"
  should_run_service secrets || return 0
  local arns
  arns=$(aws_exec "$region" secretsmanager list-secrets --query 'SecretList[].ARN' --output text || true)
  for a in $arns; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete Secret (force) in $region: $a"
    else
      aws_exec "$region" secretsmanager delete-secret --secret-id "$a" --force-delete-without-recovery >/dev/null || true
    fi
  done
}

cleanup_kms() {
  local region="$1"
  should_run_service kms || return 0
  [[ $INCLUDE_KMS -eq 1 ]] || return 0
  local keys
  keys=$(aws_exec "$region" kms list-keys --query 'Keys[].KeyId' --output text || true)
  for k in $keys; do
    # Skip AWS managed keys
    local meta
    meta=$(aws_exec "$region" kms describe-key --key-id "$k" --output json || true)
    local mgr
    mgr=$(jq -r '.KeyMetadata.KeyManager' <<<"$meta" 2>/dev/null || echo "")
    if [[ "$mgr" == "AWS" ]]; then continue; fi
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Schedule KMS key deletion in $region: $k"
    else
      aws_exec "$region" kms schedule-key-deletion --key-id "$k" --pending-window-in-days 7 >/dev/null || true
    fi
  done
}

cleanup_s3_global() {
  [[ $INCLUDE_S3 -eq 1 ]] || return 0
  should_run_service s3 || return 0
  # S3 is global namespace; iterate over all buckets then remove
  local buckets
  buckets=$(aws ${PROFILE:+--profile "$PROFILE"} s3api list-buckets --query 'Buckets[].Name' --output text || true)
  for b in $buckets; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete S3 bucket: s3://$b (empties first)"
    else
      aws ${PROFILE:+--profile "$PROFILE"} s3 rb "s3://$b" --force >/dev/null || true
    fi
  done
}

cleanup_route53_global() {
  [[ $INCLUDE_ROUTE53 -eq 1 ]] || return 0
  should_run_service route53 || return 0
  local zones
  zones=$(aws ${PROFILE:+--profile "$PROFILE"} route53 list-hosted-zones --query 'HostedZones[].Id' --output text || true)
  for zid in $zones; do
    local zid_trim=${zid##*/}
    # Delete all records except SOA/NS
    local rrsets
    rrsets=$(aws ${PROFILE:+--profile "$PROFILE"} route53 list-resource-record-sets --hosted-zone-id "$zid_trim" --output json)
    local changes
    changes=$(jq -c '{Changes: [ .ResourceRecordSets[] | select(.Type != "SOA" and .Type != "NS") | {Action:"DELETE", ResourceRecordSet:.} ]}' <<<"$rrsets")
    if [[ $(jq '.Changes | length' <<<"$changes") -gt 0 ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        confirm_or_echo "Delete Route53 records in zone $zid_trim"
      else
        aws ${PROFILE:+--profile "$PROFILE"} route53 change-resource-record-sets --hosted-zone-id "$zid_trim" --change-batch "$changes" >/dev/null || true
      fi
    fi
    # Delete hosted zone
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Delete Route53 hosted zone $zid_trim"
    else
      aws ${PROFILE:+--profile "$PROFILE"} route53 delete-hosted-zone --id "$zid_trim" >/dev/null || true
    fi
  done
}

cleanup_cloudfront_global() {
  [[ $INCLUDE_CLOUDFRONT -eq 1 ]] || return 0
  should_run_service cloudfront || return 0
  local dists
  dists=$(aws ${PROFILE:+--profile "$PROFILE"} cloudfront list-distributions --query 'DistributionList.Items[].Id' --output text || true)
  for d in $dists; do
    # Need ETag to delete
    local etag
    etag=$(aws ${PROFILE:+--profile "$PROFILE"} cloudfront get-distribution --id "$d" --query 'ETag' --output text || true)
    if [[ -z "$etag" || "$etag" == "None" ]]; then continue; fi
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Disable and delete CloudFront distribution $d"
    else
      # Disable first
      local dist_json
      dist_json=$(aws ${PROFILE:+--profile "$PROFILE"} cloudfront get-distribution-config --id "$d" --output json)
      dist_json=$(jq '.DistributionConfig.Enabled=false' <<<"$dist_json")
      local et
      et=$(jq -r '.ETag' <<<"$dist_json")
      local cfg
      cfg=$(jq -c '.DistributionConfig' <<<"$dist_json")
      aws ${PROFILE:+--profile "$PROFILE"} cloudfront update-distribution --id "$d" --if-match "$et" --distribution-config "$cfg" >/dev/null || true
      # Delete after disable propagates (not waiting here)
      aws ${PROFILE:+--profile "$PROFILE"} cloudfront delete-distribution --id "$d" --if-match "$etag" >/dev/null || true
    fi
  done
}

cleanup_vpcs_optional() {
  local region="$1"
  [[ $DELETE_VPCS -eq 1 ]] || return 0
  local vpcs
  vpcs=$(aws_exec "$region" ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].VpcId' --output text || true)
  for vpc in $vpcs; do
    if [[ $DRY_RUN -eq 1 ]]; then
      confirm_or_echo "Attempt delete VPC in $region: $vpc (must be empty)"
    else
      # Best-effort detach and delete gateways and sub-resources may still fail if non-empty
      # IGWs
      local igws
      igws=$(aws_exec "$region" ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc --query 'InternetGateways[].InternetGatewayId' --output text || true)
      for igw in $igws; do
        aws_exec "$region" ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc" >/dev/null || true
        aws_exec "$region" ec2 delete-internet-gateway --internet-gateway-id "$igw" >/dev/null || true
      done
      # Subnets
      local subnets
      subnets=$(aws_exec "$region" ec2 describe-subnets --filters Name=vpc-id,Values=$vpc --query 'Subnets[].SubnetId' --output text || true)
      for sn in $subnets; do
        aws_exec "$region" ec2 delete-subnet --subnet-id "$sn" >/dev/null || true
      done
      # Route tables (non-main)
      local rts
      rts=$(aws_exec "$region" ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc --query 'RouteTables[?Associations[?Main!=`true`]].RouteTableId' --output text || true)
      for rt in $rts; do
        aws_exec "$region" ec2 delete-route-table --route-table-id "$rt" >/dev/null || true
      done
      # Security groups (non-default)
      local sgs
      sgs=$(aws_exec "$region" ec2 describe-security-groups --filters Name=vpc-id,Values=$vpc --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text || true)
      for sg in $sgs; do
        aws_exec "$region" ec2 delete-security-group --group-id "$sg" >/dev/null || true
      done
      # NACLs (non-default)
      local nacls
      nacls=$(aws_exec "$region" ec2 describe-network-acls --filters Name=vpc-id,Values=$vpc --query 'NetworkAcls[?IsDefault==`false`].NetworkAclId' --output text || true)
      for n in $nacls; do
        aws_exec "$region" ec2 delete-network-acl --network-acl-id "$n" >/dev/null || true
      done
      # Endpoints already handled earlier
      # Finally delete VPC
      aws_exec "$region" ec2 delete-vpc --vpc-id "$vpc" >/dev/null || true
    fi
  done
}

# ------------- Main -------------

main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --execute) EXECUTE=1; DRY_RUN=0; shift ;;
      --profile) PROFILE="$2"; shift 2 ;;
      --regions) REGIONS="$2"; shift 2 ;;
      --assume-role) ASSUME_ROLE_ARN="$2"; shift 2 ;;
      --session-name) SESSION_NAME="$2"; shift 2 ;;
      --include-s3) INCLUDE_S3=1; shift ;;
      --include-snapshots) INCLUDE_SNAPSHOTS=1; shift ;;
      --include-route53) INCLUDE_ROUTE53=1; shift ;;
      --include-cloudfront) INCLUDE_CLOUDFRONT=1; shift ;;
      --include-kms) INCLUDE_KMS=1; shift ;;
      --only-services) ONLY_SERVICES="$2"; shift 2 ;;
      --skip-services) SKIP_SERVICES="$2"; shift 2 ;;
      --delete-vpcs) DELETE_VPCS=1; shift ;;
      --no-final-snapshot=false) NO_FINAL_SNAPSHOT=0; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
    esac
  done

  require_cmd aws
  require_cmd jq

  assume_role_if_needed

  log "Mode: $([[ $DRY_RUN -eq 1 ]] && echo DRY-RUN || echo EXECUTE)"
  [[ -n "$PROFILE" ]] && log "Using profile: $PROFILE"

  local regions
  regions=$(get_regions)
  log "Regions: $(tr '\n' ' ' <<<"$regions")"

  # Global services first
  cleanup_s3_global
  cleanup_route53_global
  cleanup_cloudfront_global

  # Per-region cleanup
  while IFS= read -r region; do
    [[ -z "$region" ]] && continue
    log "--- Region: $region ---"
    cleanup_ec2_instances "$region"
    cleanup_elbv2 "$region"
    cleanup_elb_classic "$region"
    cleanup_eips "$region"
    cleanup_nat_gateways "$region"
    cleanup_vpc_endpoints "$region"
    cleanup_ebs_volumes "$region"
    cleanup_ebs_snapshots "$region"
    cleanup_rds "$region"
    cleanup_eks "$region"
    cleanup_ecs "$region"
    cleanup_ecr "$region"
    cleanup_opensearch "$region"
    cleanup_elasticache "$region"
    cleanup_redshift "$region"
    cleanup_dynamodb "$region"
    cleanup_secrets "$region"
    cleanup_kms "$region"
    cleanup_vpcs_optional "$region"
  done <<< "$regions"

  log "Done. Note: Some deletions are asynchronous and may take minutes to complete."
}

main "$@"
