package test

import (
  "os/exec"
  "regexp"
  "strings"
  "testing"

  "github.com/gruntwork-io/terratest/modules/random"
  "github.com/gruntwork-io/terratest/modules/terraform"
  "github.com/stretchr/testify/assert"
  "k8s.io/apimachinery/pkg/util/runtime"
)

// Test the Terraform module in examples/complete using Terratest.
func TestExamplesComplete(t *testing.T) {
  // This module needs to be run inside a Git Repository, so we cannot run it in parallel
  // t.Parallel()

  // If running on a GitHub Action Runner, invoke the necessary blessing
  cmd := exec.Command("bash", "-c", "[[ -d /__w/actions/actions ]] && git config --global --add safe.directory /__w/actions/actions || true")
  var stdout strings.Builder
  cmd.Stdout = &stdout
  var stderr strings.Builder
  cmd.Stderr = &stderr

  if err := cmd.Run(); err != nil {
    t.Logf("Running command: %s", cmd.String())
    t.Logf("command stdout: %s", stdout.String())
    t.Logf("command stderr: %s", stderr.String())
    t.Log(err)
  }

  randID := strings.ToLower(random.UniqueId())
  attributes := []string{randID}

  varFiles := []string{"fixtures.us-east-2.tfvars"}

  terraformOptions := &terraform.Options{
    // The path to where our Terraform code is located
    TerraformDir: "../../examples/complete",
    Upgrade:      true,
    // Variables to pass to our Terraform code using -var-file options
    VarFiles: varFiles,
    Vars: map[string]interface{}{
      "attributes": attributes,
    },
  }

  // At the end of the test, run `terraform destroy` to clean up any resources that were created
  defer terraform.Destroy(t, terraformOptions)

  // If Go runtime crushes, run `terraform destroy` to clean up any resources that were created
  defer runtime.HandleCrash(func(i interface{}) {
    defer terraform.Destroy(t, terraformOptions)
  })

  // This will run `terraform init` and `terraform apply` and fail the test if there are any errors
  terraform.InitAndApply(t, terraformOptions)

  lambdaFunctionName := terraform.Output(t, terraformOptions, "lambda_forwarder_log_function_name")
  assert.Equal(t, "eg-ue2-test-datadog-lambda-forwarder-"+randID+"-logs", lambdaFunctionName)
}

func TestExamplesCompleteDisabled(t *testing.T) {
  // This module needs to be run inside a Git Repository, so we cannot run it in parallel
  // t.Parallel()

  randID := strings.ToLower(random.UniqueId())
  attributes := []string{randID}

  varFiles := []string{"fixtures.us-east-2.tfvars"}

  terraformOptions := &terraform.Options{
    // The path to where our Terraform code is located
    TerraformDir: "../../examples/complete",
    Upgrade:      true,
    // Variables to pass to our Terraform code using -var-file options
    VarFiles: varFiles,
    Vars: map[string]interface{}{
      "attributes": attributes,
      "enabled":    false,
    },
  }

  // At the end of the test, run `terraform destroy` to clean up any resources that were created
  defer terraform.Destroy(t, terraformOptions)

  // If Go runtime crushes, run `terraform destroy` to clean up any resources that were created
  defer runtime.HandleCrash(func(i interface{}) {
    defer terraform.Destroy(t, terraformOptions)
  })

  // This will run `terraform init` and `terraform apply` and fail the test if there are any errors
  results := terraform.InitAndApply(t, terraformOptions)

  // Should complete successfully without creating or changing any resources.
  // Extract the "Resources:" section of the output to make the error message more readable.
  re := regexp.MustCompile(`Resources: [^.]+\.`)
  match := re.FindString(results)
  assert.Equal(t, "Resources: 0 added, 0 changed, 0 destroyed.", match, "Re-applying the same configuration should not change any resources")
}
