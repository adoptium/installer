<#
.SYNOPSIS
    This script verifies the validity an input, given a list of possible inputs.

.DESCRIPTION
    The script takes a string as input and checks if it is valid against a list of valid inputs.
    If the input is valid, the script returns 0. If the input is invalid, the script returns 1.

.PARAMETER validInputs
    A comma seperated list of valid inputs.

.PARAMETER toValidate
    The input to be verified.

.PARAMETER delimiter
    The delimiter used to split the input string. Default is a space.

.NOTES
    File Name: Validate-Input.ps1
    Author   : Joshua Martin-Jaffe
    Version  : 1.0
    Date     : Feb. 29, 2024

.EXAMPLE
    PS> .\Validate-Input.ps1 -validInputs 'x86-32 x64' -toValidate 'x86-32 x64' -delimiter ' '

    True

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$validInputs,
    [Parameter(Mandatory = $true)]
    [string]$toValidate,
    [Parameter(Mandatory = $true)]
    [string]$delimiter
)

$validInputs = $validInputs.Trim("'")
$validInputArray = $ -split "$delimiter"

$toValidate = $toValidate.Trim("'")
$inputArray = $toValidate -split "$delimiter"


for ($i = 0; $i -lt $inputArray.Length; $i++) {
    if ($validInputArray -notcontains $inputArray[$i]) {
        echo $inputArray[$i] ' is an invalid input'
        exit 1 # Invalid input
    }
}
exit 0 # Valid input