/**
 * @description Simple validator to check if Google_Gmail_NC named credential exists and is accessible
 * This utility can be used in anonymous apex or from other classes to quickly diagnose issues
 */
public with sharing class GmailNamedCredentialValidator {
    
    /**
     * Simple validation method that returns basic information about the named credential
     * @return String with validation status
     */
    @AuraEnabled
    public static String validateNamedCredential() {
        try {
            // Try to make a simple call to the Gmail API using the named credential
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint('callout:Google_Gmail_NC/gmail/v1/users/me/profile');
            
            Http http = new Http();
            HttpResponse httpRes = http.send(req);
            
            if (httpRes.getStatusCode() == 200) {
                return 'SUCCESS: Named credential is properly configured and authorized.';
            } else if (httpRes.getStatusCode() == 401 || httpRes.getStatusCode() == 403) {
                return 'ERROR: Named credential is not authorized. Please re-authorize in Setup > Security > Named Credentials.';
            } else if (httpRes.getStatusCode() == 404) {
                return 'ERROR: Named credential endpoint not found. Check the endpoint URL in the named credential configuration.';
            } else {
                return 'ERROR: Unexpected HTTP status ' + httpRes.getStatusCode() + '. Details: ' + httpRes.getStatus();
            }
        } catch (Exception ex) {
            String errorMsg = ex.getMessage();
            if (errorMsg.contains('named credential') || errorMsg.contains('Named Credential') || errorMsg.contains('callout')) {
                return 'ERROR: Named credential "Google_Gmail_NC" does not exist in this org. Please create it in Setup > Security > Named Credentials.';
            } else if (errorMsg.contains('endpoint') || errorMsg.contains('Endpoint')) {
                return 'ERROR: Endpoint configuration issue. Please verify the named credential endpoint URL.';
            } else {
                return 'ERROR: Exception occurred: ' + errorMsg;
            }
        }
    }
    
    /**
     * Method to check if a specific named credential exists
     * @param credentialName The name of the named credential to check
     * @return Boolean indicating if the named credential exists
     */
    public static Boolean namedCredentialExists(String credentialName) {
        try {
            // Try to query the NamedCredential object
            List<NamedCredential> creds = [
                SELECT Id, DeveloperName 
                FROM NamedCredential 
                WHERE DeveloperName = :credentialName 
                LIMIT 1
            ];
            return !creds.isEmpty();
        } catch (Exception e) {
            return false;
        }
    }
}
