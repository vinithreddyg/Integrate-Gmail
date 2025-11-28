/**
 * @description Diagnostic utility for Gmail Named Credential issues
 * Provides detailed checks and suggestions for troubleshooting Gmail API integration
 */
public with sharing class GmailNamedCredentialDiagnostic {
    
    /**
     * Diagnostic result DTO
     */
    public class DiagnosticResult {
        public Boolean success;
        public String statusMessage;
        public String detailedMessage;
        public List<String> suggestions;
        public Boolean namedCredentialExists;
        public Boolean namedCredentialAuthorized;
        public Boolean scopesValid;
        public String emailAddress;
    }
    
    /**
     * Comprehensive diagnostic check for Gmail Named Credential setup
     * This method performs multiple checks to identify potential issues with the Google_Gmail_NC named credential
     */
    @AuraEnabled(cacheable=false)
    public static DiagnosticResult diagnose() {
        DiagnosticResult result = new DiagnosticResult();
        result.suggestions = new List<String>();
        result.namedCredentialExists = false;
        result.namedCredentialAuthorized = false;
        result.scopesValid = false;
        result.success = false;
        result.statusMessage = 'Diagnostic incomplete - checking named credential configuration...';
        result.detailedMessage = '';
        
        try {
            // First, check if we can access the named credential endpoint at all
            // We'll make a simple call to the profile endpoint to test connectivity
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint('callout:Google_Gmail_NC/gmail/v1/users/me/profile');
            
            Http http = new Http();
            HttpResponse httpRes = http.send(req);
            
            // If we get a response, check what kind it is
            if (httpRes.getStatusCode() == 200) {
                // Success - credential is likely working
                result.success = true;
                result.statusMessage = 'Named Credential appears to be configured correctly';
                result.detailedMessage = 'Successfully accessed Gmail API profile endpoint with named credential "' + 'Google_Gmail_NC' + '"';
                
                // Parse the response to get email info
                try {
                    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                    result.emailAddress = (String) payload.get('emailAddress');
                    result.namedCredentialExists = true;
                    result.namedCredentialAuthorized = true;
                    result.scopesValid = true;
                } catch (Exception e) {
                    result.detailedMessage += ' - Could not parse response: ' + e.getMessage();
                }
            } else if (httpRes.getStatusCode() == 401 || httpRes.getStatusCode() == 403) {
                // Unauthorized - likely credential not authorized or scopes incorrect
                result.success = false;
                result.statusMessage = 'Named Credential not authorized or insufficient permissions';
                result.detailedMessage = 'Received HTTP ' + httpRes.getStatusCode() + ' when accessing Gmail API. This typically means the named credential is not authorized or has incorrect scopes.';
                result.namedCredentialExists = true;
                result.namedCredentialAuthorized = false;
                result.scopesValid = false;
                result.suggestions.add('Verify that the named credential is properly authorized in Salesforce Setup.');
                result.suggestions.add('Check that the OAuth scopes include "https://www.googleapis.com/auth/gmail.send"');
                result.suggestions.add('Re-authorize the named credential if needed.');
            } else if (httpRes.getStatusCode() == 404) {
                // Not found - likely endpoint issue or credential misconfiguration
                result.success = false;
                result.statusMessage = 'Endpoint not found or named credential misconfigured';
                result.detailedMessage = 'Received HTTP 404 when accessing Gmail API. This suggests the endpoint URL in the named credential may be incorrect or the named credential is not properly configured.';
                result.namedCredentialExists = true;
                result.namedCredentialAuthorized = false; // We can't tell for sure, but likely not authorized
                result.suggestions.add('Verify the named credential endpoint URL is correct: https://gmail.googleapis.com/');
                result.suggestions.add('Ensure the named credential is configured with the correct identity type.');
                result.suggestions.add('Check that the endpoint path in your callout is correct.');
            } else if (httpRes.getStatusCode() == 400) {
                // Bad request - likely malformed request or credential issue
                result.success = false;
                result.statusMessage = 'Bad Request - possible credential or request issue';
                result.detailedMessage = 'Received HTTP 400 when accessing Gmail API. This often indicates a malformed request or an issue with the named credential configuration.';
                result.namedCredentialExists = true;
                result.namedCredentialAuthorized = false; // We can't tell for sure, but likely not authorized
                result.suggestions.add('Verify the named credential is properly configured.');
                result.suggestions.add('Check that the endpoint path in your callout is correct.');
                result.suggestions.add('Verify that the named credential has proper OAuth scopes.');
            } else {
                // Other error codes
                result.success = false;
                result.statusMessage = 'Named Credential access error';
                result.detailedMessage = 'Received HTTP ' + httpRes.getStatusCode() + ' when accessing Gmail API. Error: ' + httpRes.getStatus();
                result.suggestions.add('Check the named credential configuration in Salesforce Setup.');
                result.suggestions.add('Verify the endpoint URL and authentication settings.');
            }
        } catch (Exception ex) {
            String errorMsg = ex.getMessage();
            result.success = false;
            result.statusMessage = 'Named Credential access failed';
            result.detailedMessage = 'Exception occurred while testing named credential: ' + errorMsg;
            result.namedCredentialExists = false;
            result.namedCredentialAuthorized = false;
            result.scopesValid = false;
            
            // Try to provide more specific guidance based on error message
            if (errorMsg.contains('named credential') || errorMsg.contains('Named Credential') || errorMsg.contains('callout')) {
                result.suggestions.add('The named credential "Google_Gmail_NC" does not exist in this org.');
                result.suggestions.add('Create the named credential in Setup > Security > Named Credentials.');
                result.suggestions.add('Follow the setup instructions in the README.md file.');
            } else if (errorMsg.contains('endpoint') || errorMsg.contains('Endpoint')) {
                result.suggestions.add('The endpoint URL in the named credential may be incorrect.');
                result.suggestions.add('Verify the named credential endpoint is set to: https://gmail.googleapis.com/');
            } else if (errorMsg.contains('redirect') || errorMsg.contains('Redirect')) {
                result.suggestions.add('OAuth redirect URI mismatch - check the Salesforce Auth Provider callback URL.');
                result.suggestions.add('Update Google OAuth client Authorized redirect URIs to match Salesforce Auth Provider Callback URL.');
            } else if (errorMsg.contains('401') || errorMsg.contains('403')) {
                result.suggestions.add('Authentication failed - verify the named credential is authorized.');
                result.suggestions.add('Re-authorize the named credential in Setup > Security > Named Credentials.');
            } else if (errorMsg.contains('404')) {
                result.suggestions.add('Endpoint not found - verify the named credential endpoint URL.');
                result.suggestions.add('Ensure the endpoint path in your callout is correct.');
            } else {
                result.suggestions.add('Check the named credential configuration in Salesforce Setup.');
                result.suggestions.add('Verify all required fields are populated correctly.');
            }
        }
        
        return result;
    }
}
