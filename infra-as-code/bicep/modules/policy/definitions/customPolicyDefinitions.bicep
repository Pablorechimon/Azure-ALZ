targetScope = 'managementGroup'

metadata name = 'ALZ Bicep - Custom Policy Defitions at Management Group Scope'
metadata description = 'This policy definition is used to deploy custom policy definitions at management group scope'

@sys.description('The management group scope to which the policy definitions are to be created at.')
param parTargetManagementGroupId string = 'alz'

@sys.description('Set Parameter to true to Opt-out of deployment telemetry')
param parTelemetryOptOut bool = false

var varTargetManagementGroupResourceId = tenantResourceId('Microsoft.Management/managementGroups', parTargetManagementGroupId)

// This variable contains a number of objects that load in the custom Azure Policy Defintions that are provided as part of the ESLZ/ALZ reference implementation - this is automatically created in the file 'infra-as-code\bicep\modules\policy\lib\policy_definitions\_policyDefinitionsBicepInput.txt' via a GitHub action, that runs on a daily schedule, and is then manually copied into this variable.
var varCustomPolicyDefinitionsArray = [
  {
    name: 'Deny-Storage-SFTP'
    libDefinition: loadJsonContent('lib/definitions/policy_definition_es_Deny-Storage-SFTP.json')
  }
]
var varCustomPolicySetDefinitionsArray = []

// Policy Set/Initiative Definition Parameter Variables

// var varPolicySetDefinitionEsAuditUnusedResourcesCostOptimizationParameters = loadJsonContent('')

// Customer Usage Attribution Id
var varCuaid = '2b136786-9881-412e-84ba-f4c2822e1ac9'

resource resPolicyDefinitions 'Microsoft.Authorization/policyDefinitions@2021-06-01' = [for policy in varCustomPolicyDefinitionsArray: {
  name: policy.libDefinition.name
  properties: {
    description: policy.libDefinition.properties.description
    displayName: policy.libDefinition.properties.displayName
    metadata: policy.libDefinition.properties.metadata
    mode: policy.libDefinition.properties.mode
    parameters: policy.libDefinition.properties.parameters
    policyType: policy.libDefinition.properties.policyType
    policyRule: policy.libDefinition.properties.policyRule
  }
}]

resource resPolicySetDefinitions 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = [for policySet in varCustomPolicySetDefinitionsArray: {
  dependsOn: [
    resPolicyDefinitions // Must wait for policy definitons to be deployed before starting the creation of Policy Set/Initiative Defininitions
  ]
  name: policySet.libSetDefinition.name
  properties: {
    description: policySet.libSetDefinition.properties.description
    displayName: policySet.libSetDefinition.properties.displayName
    metadata: policySet.libSetDefinition.properties.metadata
    parameters: policySet.libSetDefinition.properties.parameters
    policyType: policySet.libSetDefinition.properties.policyType
    policyDefinitions: [for policySetDef in policySet.libSetChildDefinitions: {
      policyDefinitionReferenceId: policySetDef.definitionReferenceId
      policyDefinitionId: policySetDef.definitionId
      parameters: policySetDef.definitionParameters
      groupNames: policySetDef.definitionGroups
    }]
    policyDefinitionGroups: policySet.libSetDefinition.properties.policyDefinitionGroups
  }
}]

// Optional Deployment for Customer Usage Attribution
module modCustomerUsageAttribution '../../../CRML/customerUsageAttribution/cuaIdManagementGroup.bicep' = if (!parTelemetryOptOut) {
  #disable-next-line no-loc-expr-outside-params //Only to ensure telemetry data is stored in same location as deployment. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  name: 'pid-${varCuaid}-${uniqueString(deployment().location)}'
  params: {}
}
