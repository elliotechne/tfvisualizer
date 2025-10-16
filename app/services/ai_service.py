"""
AI Service
Provides AI-powered features using Anthropic Claude API
"""

import os
import anthropic
from app.utils.logger import setup_logger

logger = setup_logger(__name__)


class AIService:
    """AI service for infrastructure design and optimization"""

    def __init__(self):
        self.api_key = os.getenv('ANTHROPIC_API_KEY')
        if self.api_key:
            self.client = anthropic.Anthropic(api_key=self.api_key)
        else:
            self.client = None
            logger.warning("ANTHROPIC_API_KEY not configured - AI features disabled")

    def is_available(self):
        """Check if AI service is available"""
        return self.client is not None

    def analyze_cost_optimization(self, resources, current_cost):
        """
        Analyze infrastructure design and suggest cost optimizations

        Args:
            resources: List of resources in the design
            current_cost: Current estimated monthly cost

        Returns:
            dict with optimization suggestions
        """
        if not self.is_available():
            return {
                'available': False,
                'error': 'AI service not configured'
            }

        try:
            # Build context about the infrastructure
            resource_summary = self._build_resource_summary(resources)

            prompt = f"""You are an expert cloud infrastructure cost optimization consultant. Analyze this Terraform infrastructure design and provide specific cost optimization recommendations.

Current Infrastructure:
{resource_summary}

Current Estimated Monthly Cost: ${current_cost}

Please provide:
1. **Cost Optimization Opportunities** - List specific resources that could be optimized and how
2. **Estimated Savings** - Approximate monthly savings for each recommendation
3. **Implementation Difficulty** - Rate each suggestion as Easy/Medium/Hard
4. **Risk Assessment** - Note any performance or availability trade-offs

Format your response as JSON with this structure:
{{
  "summary": "Brief overview of optimization potential",
  "total_potential_savings": "Estimated total monthly savings",
  "recommendations": [
    {{
      "resource": "Resource name/type",
      "current": "Current configuration",
      "optimized": "Recommended configuration",
      "monthly_savings": "Estimated savings",
      "difficulty": "Easy/Medium/Hard",
      "impact": "Description of changes needed",
      "risks": "Any performance/availability concerns"
    }}
  ],
  "quick_wins": ["List of easiest optimizations to implement first"]
}}

Provide practical, actionable recommendations."""

            message = self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=2048,
                temperature=0.3,
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            )

            response_text = message.content[0].text

            return {
                'available': True,
                'success': True,
                'analysis': response_text,
                'usage': {
                    'input_tokens': message.usage.input_tokens,
                    'output_tokens': message.usage.output_tokens
                }
            }

        except Exception as e:
            logger.error(f"Cost optimization AI error: {str(e)}")
            return {
                'available': True,
                'success': False,
                'error': str(e)
            }

    def generate_design(self, user_prompt, cloud_provider='aws'):
        """
        Generate infrastructure design from natural language description (streaming)

        Args:
            user_prompt: Natural language description of desired infrastructure
            cloud_provider: Target cloud provider (aws, gcp, azure, digitalocean, kubernetes)

        Returns:
            Generator that yields chunks of the response
        """
        if not self.is_available():
            yield {
                'available': False,
                'error': 'AI service not configured'
            }
            return

        try:
            # Provider-specific resource types
            provider_resources = self._get_provider_resources(cloud_provider)

            prompt = f"""You are an expert cloud infrastructure architect. Generate a Terraform infrastructure design based on the user's requirements.

User Request: {user_prompt}

Target Cloud Provider: {cloud_provider}

Available Resource Types:
{provider_resources}

Generate a complete infrastructure design and provide:

1. **Architecture Overview** - High-level description of the design
2. **Resource List** - Specific resources to create with configuration details
3. **Rationale** - Why you chose this architecture
4. **Estimated Monthly Cost** - Rough cost estimate
5. **Best Practices** - Security, scalability, and reliability considerations

Format your response as JSON with this structure:
{{
  "overview": "Architecture description",
  "estimated_cost": "Monthly cost estimate",
  "resources": [
    {{
      "type": "Resource type (e.g., aws_instance, aws_vpc)",
      "name": "Descriptive name",
      "configuration": {{
        "property1": "value1",
        "property2": "value2"
      }},
      "rationale": "Why this resource is needed"
    }}
  ],
  "connections": [
    {{
      "from": "resource1_name",
      "to": "resource2_name",
      "description": "Why they're connected"
    }}
  ],
  "best_practices": ["List of important considerations"],
  "next_steps": ["Recommended follow-up actions"]
}}

Provide a production-ready, well-architected design."""

            # Stream the response
            with self.client.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=3072,
                temperature=0.5,
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            ) as stream:
                for text in stream.text_stream:
                    yield text

        except Exception as e:
            logger.error(f"Design generation AI error: {str(e)}")
            yield {
                'error': str(e)
            }

    def _build_resource_summary(self, resources):
        """Build a summary of resources for AI analysis"""
        summary = []

        # Group by type
        by_type = {}
        for resource in resources:
            rtype = resource.get('type', 'unknown')
            if rtype not in by_type:
                by_type[rtype] = []
            by_type[rtype].append(resource)

        for rtype, items in by_type.items():
            count = len(items)
            # Extract key configuration details
            configs = []
            for item in items:
                config_details = []
                if 'instanceType' in item:
                    config_details.append(f"Type: {item['instanceType']}")
                if 'size' in item:
                    config_details.append(f"Size: {item['size']}")
                if 'volumeSize' in item:
                    config_details.append(f"Volume: {item['volumeSize']}GB")

                if config_details:
                    configs.append(f"  - {item.get('name', 'unnamed')}: {', '.join(config_details)}")
                else:
                    configs.append(f"  - {item.get('name', 'unnamed')}")

            summary.append(f"- {rtype} ({count}x):")
            summary.extend(configs[:5])  # Limit to first 5 to avoid token overflow
            if len(configs) > 5:
                summary.append(f"  ... and {len(configs) - 5} more")

        return "\n".join(summary)

    def _get_provider_resources(self, provider):
        """Get available resource types for a provider"""
        resources_map = {
            'aws': """
- Compute: aws_instance (EC2), aws_autoscaling_group, aws_lambda_function
- Networking: aws_vpc, aws_subnet, aws_security_group, aws_lb (Load Balancer), aws_nat_gateway
- Storage: aws_s3_bucket, aws_ebs_volume, aws_efs_file_system
- Database: aws_rds_instance, aws_dynamodb_table, aws_elasticache_cluster
- Container: aws_ecs_cluster, aws_ecs_service, aws_eks_cluster
""",
            'gcp': """
- Compute: google_compute_instance, google_compute_instance_group, google_cloud_function
- Networking: google_compute_network, google_compute_subnetwork, google_compute_firewall, google_compute_forwarding_rule
- Storage: google_storage_bucket, google_compute_disk
- Database: google_sql_database_instance, google_bigtable_instance
- Container: google_container_cluster (GKE), google_container_node_pool
""",
            'azure': """
- Compute: azurerm_virtual_machine, azurerm_linux_virtual_machine, azurerm_function_app
- Networking: azurerm_virtual_network, azurerm_subnet, azurerm_network_security_group, azurerm_lb
- Storage: azurerm_storage_account, azurerm_managed_disk
- Database: azurerm_postgresql_server, azurerm_cosmosdb_account, azurerm_sql_database
- Container: azurerm_kubernetes_cluster (AKS), azurerm_container_group
""",
            'digitalocean': """
- Compute: digitalocean_droplet, digitalocean_kubernetes_cluster
- Networking: digitalocean_vpc, digitalocean_firewall, digitalocean_loadbalancer
- Storage: digitalocean_volume, digitalocean_spaces_bucket
- Database: digitalocean_database_cluster
- Other: digitalocean_cdn, digitalocean_domain
""",
            'kubernetes': """
- Workloads: kubernetes_deployment, kubernetes_stateful_set, kubernetes_daemon_set, kubernetes_job
- Networking: kubernetes_service, kubernetes_ingress, kubernetes_network_policy
- Storage: kubernetes_persistent_volume, kubernetes_persistent_volume_claim, kubernetes_storage_class
- Config: kubernetes_config_map, kubernetes_secret, kubernetes_service_account
- Scaling: kubernetes_horizontal_pod_autoscaler
"""
        }

        return resources_map.get(provider, "Standard Terraform resources")
