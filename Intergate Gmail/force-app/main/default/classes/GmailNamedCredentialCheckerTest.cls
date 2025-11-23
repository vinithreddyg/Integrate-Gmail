@IsTest
private class GmailNamedCredentialCheckerTest {

    // Mock for GET users/me/profile
    private class MockProfileResponse implements HttpCalloutMock {
        Integer statusCode;
        String body;
        MockProfileResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('GET', req.getMethod(), 'Expected GET');
            System.assert(req.getEndpoint().contains('callout:Google_Gmail_NC/gmail/v1/users/me/profile'),
                          'Endpoint mismatch: ' + req.getEndpoint());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void checkProfile_success() {
        String body = '{"emailAddress":"user@example.com","messagesTotal":100,"threadsTotal":20,"historyId":"987654"}';
        Test.setMock(HttpCalloutMock.class, new MockProfileResponse(200, body));

        Test.startTest();
        GmailNamedCredentialChecker.CheckResult result = GmailNamedCredentialChecker.checkProfile();
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected success');
        System.assertEquals(200, result.statusCode, 'Status code mismatch');
        System.assertEquals('user@example.com', result.emailAddress, 'Email mismatch');
        System.assertEquals('987654', result.historyId, 'HistoryId mismatch');
        System.assert(result.errorMessage == null, 'No error expected');
        System.assert(result.rawBody != null && result.rawBody.contains('emailAddress'), 'Raw body retained');
    }

    @IsTest
    static void checkProfile_unauthorized() {
        Test.setMock(HttpCalloutMock.class, new MockProfileResponse(401, '{"error":"unauthorized"}'));

        Test.startTest();
        GmailNamedCredentialChecker.CheckResult result = GmailNamedCredentialChecker.checkProfile();
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure');
        System.assertEquals(401, result.statusCode, 'Status code mismatch');
        System.assert(result.errorMessage != null && result.errorMessage.startsWith('HTTP 401'), 'Error message should include 401');
    }
}
