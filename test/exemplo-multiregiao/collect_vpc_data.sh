#!/bin/bash

REGIONS=("us-east-1" "sa-east-1")
REPORT_DIR="client-reports"
OUTPUT_FILE="$REPORT_DIR/vpc_inventory.csv"

mkdir -p "$REPORT_DIR"

# Buscar profiles com prefixo CL037-
PROFILES=$(grep -E '^\[profile CL037-' ~/.aws/config | sed 's/\[profile \(.*\)\]/\1/')

echo "Profiles encontrados:"
echo "$PROFILES"
echo ""

# Criar CSV com cabeçalho
echo "AWS_PROFILE,AWS_REGION,VPC_ID,VPC_NAME,IPV4_CIDR,IS_DEFAULT_VPC" > "$OUTPUT_FILE"

# Iterar sobre profiles e regiões
for PROFILE in $PROFILES; do
    for REGION in "${REGIONS[@]}"; do
        echo "Processando: $PROFILE - $REGION"
        
        # Listar VPCs
        VPCS=$(aws ec2 describe-vpcs --profile "$PROFILE" --region "$REGION" --output json 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo "$VPCS" | jq -r '.Vpcs[] | [
                "'$PROFILE'",
                "'$REGION'",
                .VpcId,
                ((.Tags // [] | map(select(.Key=="Name")) | .[0].Value) // ""),
                .CidrBlock,
                .IsDefault
            ] | @csv' >> "$OUTPUT_FILE"
        fi
    done
done

echo ""
echo "Dados salvos em: $OUTPUT_FILE"
