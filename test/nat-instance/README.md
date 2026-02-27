# Exemplo de VPC com NAT Instance

Este exemplo demonstra como criar uma VPC com NAT Instance para fornecer acesso à internet para recursos em subnets privadas.

## Visão Geral

NAT Instances são instâncias EC2 configuradas para realizar Network Address Translation (NAT), permitindo que recursos em subnets privadas acessem a internet sem expor seus endereços IP privados.

### Quando usar NAT Instance vs NAT Gateway

**NAT Instance:**
- ✅ Custo mais baixo (apenas custo da instância EC2)
- ✅ Maior controle e customização
- ✅ Pode ser usado como bastion host
- ❌ Requer gerenciamento manual
- ❌ Não é altamente disponível por padrão
- ❌ Pode ser gargalo de performance

**NAT Gateway:**
- ✅ Gerenciado pela AWS
- ✅ Alta disponibilidade automática
- ✅ Melhor performance
- ❌ Custo mais alto ($0.045/hora + $0.045/GB)
- ❌ Menos flexível

## Arquitetura

```
Internet
    |
    v
Internet Gateway
    |
    v
Subnet Pública (10.100.0.0/20)
    |
    v
NAT Instance (t3.medium)
    |
    v
Subnet Privada (10.100.128.0/20)
    |
    v
Recursos Privados (EC2, RDS, etc)
```

## Pré-requisitos

Antes de aplicar este exemplo, você precisa criar uma AMI customizada para o NAT Instance seguindo o guia em [`docs/nat-instance-ami-setup.md`](../../docs/nat-instance-ami-setup.md).

### Por que preciso criar uma AMI customizada?

A AWS descontinuou as AMIs oficiais de NAT Instance. A solução é criar sua própria AMI baseada no Amazon Linux 2023 com as configurações necessárias:

1. IP forwarding habilitado
2. iptables configurado para MASQUERADE
3. Source/destination check desabilitado

**Importante:** A configuração do iptables deve detectar automaticamente a interface de rede primária, pois o nome pode variar (`eth0`, `ens5`, `enX0`).

## Configuração

### 1. Criar a AMI do NAT Instance

Siga o guia completo em [`docs/nat-instance-ami-setup.md`](../../docs/nat-instance-ami-setup.md).

Resumo dos passos:
```bash
# 1. Criar IAM Instance Profile para SSM
aws iam create-role --role-name EC2-SSM-Role ...
aws iam create-instance-profile --instance-profile-name EC2-SSM-Profile ...

# 2. Lançar instância base
aws ec2 run-instances --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 ...

# 3. Configurar NAT (via SSM)
# Instalar iptables, habilitar IP forwarding, configurar MASQUERADE

# 4. Criar AMI
aws ec2 create-image --instance-id <INSTANCE_ID> --name "nat-instance-$(date +%Y%m%d-%H%M%S)" ...
```

### 2. Atualizar o main.tf

Após criar a AMI, atualize o `ami_id` no arquivo `main.tf`:

```hcl
nat_instance = {
  create               = true
  ami_id               = "ami-XXXXXXXXXXXXXXXXX"  # Sua AMI customizada
  key_name             = "nat-instance-temp"
  iam_instance_profile = "EC2-SSM-Profile"
  az_widerange         = 1  # Número de NAT instances (1 por AZ)
  instance_tags = {
    "Name" = "nat-instance-security-vpc"
  }
}
```

### 3. Aplicar a configuração

```bash
cd test/nat-instance

# Inicializar Terraform
terraform init

# Revisar o plano
terraform plan

# Aplicar
terraform apply
```

## Recursos Criados

Este exemplo cria:

- **1 VPC** (10.100.0.0/16)
- **3 Subnets Públicas** (10.100.0.0/20, 10.100.16.0/20, 10.100.32.0/20)
- **3 Subnets Privadas** (10.100.128.0/20, 10.100.144.0/20, 10.100.160.0/20)
- **1 Internet Gateway**
- **1 NAT Instance** (t3.medium em AZ1)
- **1 Elastic IP** para o NAT Instance
- **Route Tables** configuradas automaticamente
- **Security Groups** (allowlist e NAT instance)
- **Network ACLs** configuradas

## Testando a Configuração

### 1. Verificar o NAT Instance

```bash
# Conectar via SSM
aws ssm start-session --target <NAT_INSTANCE_ID> --region us-east-1

# Verificar IP forwarding
sysctl net.ipv4.ip_forward
# Deve retornar: net.ipv4.ip_forward = 1

# Verificar iptables
sudo iptables -t nat -L POSTROUTING -n -v
# Deve mostrar regra MASQUERADE na interface correta (ens5, enX0, etc)

# Testar conectividade
ping -c 3 8.8.8.8
curl -I https://www.google.com
```

### 2. Testar de uma instância privada

Lance uma instância EC2 na subnet privada e teste:

```bash
# Conectar via SSM (se configurado)
aws ssm start-session --target <PRIVATE_INSTANCE_ID> --region us-east-1

# Testar conectividade internet
ping -c 3 8.8.8.8
curl -I https://www.google.com

# Verificar rota padrão
ip route
# Deve mostrar rota default via NAT instance
```

## Troubleshooting

### SSM não funciona em instâncias privadas

**Sintomas:**
- SSM funciona em instâncias públicas
- SSM não funciona em instâncias privadas
- Instância privada não aparece no SSM console

**Diagnóstico:**

1. Verificar se o NAT instance está funcionando:
```bash
# No NAT instance
sudo tcpdump -i ens5 host <PRIVATE_INSTANCE_IP> -n -v
```

2. Verificar regras iptables:
```bash
sudo iptables -t nat -L POSTROUTING -n -v
# Verificar se a interface está correta (ens5, não eth0)
# Verificar se o contador de pacotes está aumentando
```

3. Verificar se a instância privada está enviando tráfego:
```bash
# No NAT instance, monitorar tráfego
sudo tcpdump -i ens5 host <PRIVATE_IP> and port 443 -n
```

**Soluções comuns:**

1. **Interface incorreta no iptables:**
```bash
# Detectar interface correta
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Corrigir regra
sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE
sudo service iptables save
```

2. **Aguardar registro do SSM agent:**
   - Pode levar 5-15 minutos na primeira vez
   - Verificar se a instância está registrada:
   ```bash
   aws ssm describe-instance-information --region us-east-1
   ```

3. **Verificar IAM Instance Profile:**
   - Instância deve ter role com `AmazonSSMManagedInstanceCore`

### NAT Instance não está encaminhando tráfego

**Verificar:**

1. Source/destination check desabilitado:
```bash
aws ec2 describe-instances --instance-ids <NAT_INSTANCE_ID> \
  --query 'Reservations[].Instances[].SourceDestCheck' --region us-east-1
# Deve retornar: false
```

2. Rota configurada corretamente:
```bash
aws ec2 describe-route-tables --filters "Name=tag:subnet_layer,Values=private" --region us-east-1
# Verificar se há rota 0.0.0.0/0 apontando para o NAT instance
```

3. Security group permite tráfego:
```bash
# Security group do NAT deve permitir tráfego da subnet privada
```

## Custos Estimados (us-east-1)

- **NAT Instance (t3.medium):** ~$30/mês (24/7)
- **Elastic IP:** Grátis (enquanto associado)
- **Transferência de dados:** $0.09/GB (saída para internet)

**Comparação com NAT Gateway:**
- NAT Gateway: ~$32/mês + $0.045/GB
- NAT Instance é mais econômico para tráfego > 1TB/mês

## Limpeza

```bash
terraform destroy
```

**Nota:** Lembre-se de deletar a AMI customizada se não for mais necessária:

```bash
# Listar AMIs
aws ec2 describe-images --owners self --filters "Name=name,Values=nat-instance-*" --region us-east-1

# Deletar AMI
aws ec2 deregister-image --image-id <AMI_ID> --region us-east-1

# Deletar snapshot associado
aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID> --region us-east-1
```

## Referências

- **Documentação AWS:** [Work with NAT instances](https://docs.aws.amazon.com/vpc/latest/userguide/work-with-nat-instances.html)
- **Guia de setup da AMI:** [`docs/nat-instance-ami-setup.md`](../../docs/nat-instance-ami-setup.md)
- **Documentação do módulo:** [README.md](../../README.md)

## Notas Importantes

1. **Alta Disponibilidade:** Este exemplo cria apenas 1 NAT instance. Para produção, considere:
   - Múltiplos NAT instances em diferentes AZs (`az_widerange = 2` ou `3`)
   - Auto Scaling Group já está configurado para recuperação automática

2. **Performance:** t3.medium suporta até 5 Gbps. Para maior throughput, use instâncias maiores.

3. **Segurança:** 
   - NAT instance usa security group restritivo
   - Source/destination check desabilitado (necessário para NAT)
   - Acesso SSH via key pair configurável

4. **Monitoramento:**
   - Configure CloudWatch alarms para CPU e Network
   - Use VPC Flow Logs para auditoria de tráfego
