package test

import (
	"math/rand"
	"strconv"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Test the Terraform module in examples/complete using Terratest.
func TestExamplesComplete(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())
	randID := strconv.Itoa(rand.Intn(100000))
	attributes := []string{randID}

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../examples/complete",
		Upgrade:      true,
		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{"fixtures.us-east-2.tfvars"},
		// We always include a random attribute so that parallel tests
		// and AWS resources do not interfere with each other
		Vars: map[string]interface{}{
			"attributes": attributes,
		},
	}
	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	lambdaFunctionName := terraform.Output(t, terraformOptions, "lambda_forwarder_rds_enhanced_monitoring_function_name")
	// Verify we're getting back the outputs we expect
	//assert.Contains(t, lambdaRdsArn, expectedlambdaRdsArn)

	assert.Equal(t, "eg-ue2-test-datadog-forwarder-"+randID+"-forwarder-log", lambdaFunctionName)

}

//eg-ue2-test-datadog-forwarder-28424-forwarder-log
//arn:aws:lambda:us-east-2:530139478025:function:eg-ue2-test-datadog-forwarder-forwarder-log
// Run `terraform output` to get the value of an output variable
// awsRoleName := terraform.Output(t, terraformOptions, "aws_role_name")
// // Verify we're getting back the outputs we expect
// assert.Equal(t, "eg-test-datadog-integration-"+randId, awsRoleName)
