/**
 * @description Verifies access to Gmail API via Named Credential 'Google_Gmail_NC'
 * Provides a simple GET to gmail profile endpoint and returns status/result for admin/self-checks.
 */
public with sharing class GmailNamedCredentialChecker {

    /**
     * Result DTO
     */
    public class CheckResult {
        public Boolean success;
        public Integer statusCode;
        public String errorMessage;
        public String emailAddress;
        public String historyId;
        public String rawBody;
    }

    /**
     * Performs a GET to users/me/profile to validate OAuth is authorized and token is valid.
     * Endpoint: callout:Google_Gmail_NC/gmail/v1/users/me/profile
     */
    @AuraEnabled(cacheable=false)
    public static CheckResult checkProfile() {
        CheckResult res = new CheckResult();
        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint('callout:Google_Gmail_NC/gmail/v1/users/me/profile');

            Http http = new Http();
            HttpResponse httpRes = http.send(req);

            res.statusCode = httpRes.getStatusCode();
            res.rawBody = httpRes.getBody();

            if (httpRes.getStatusCode() == 200) {
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                res.success = true;
                res.emailAddress = (String) payload.get('emailAddress');
                Object hist = payload.get('historyId');
                res.historyId = hist == null ? null : String.valueOf(hist);
                return res;
            }

            res.success = false;
            res.errorMessage = 'HTTP ' + httpRes.getStatusCode() + ': ' + httpRes.getStatus();
            return res;

        } catch (Exception ex) {
            res.success = false;
            res.errorMessage = 'Exception: ' + ex.getMessage();
            return res;
        }
    }
}
