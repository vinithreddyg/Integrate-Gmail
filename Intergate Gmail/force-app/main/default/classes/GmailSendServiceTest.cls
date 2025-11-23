@IsTest
private class GmailSendServiceTest {

    @TestSetup
    static void setup() {
        // Minimal setup; no SeeAllData, no external callouts.
    }

    // Utility to build a fake Gmail send response JSON
    private static String buildGmailSendResponse(String idVal) {
        return '{"id":"' + idVal + '","threadId":"t_123"}';
    }

    private class MockGmailSendResponse implements HttpCalloutMock {
        Integer statusCode;
        String body;
        public MockGmailSendResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod(), 'Expected POST');
            System.assert(req.getEndpoint().contains('callout:Google_Gmail_NC/gmail/v1/users/me/messages/send'),
                          'Endpoint mismatch: ' + req.getEndpoint());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void sendEmailSync_success() {
        Test.setMock(HttpCalloutMock.class, new MockGmailSendResponse(200, buildGmailSendResponse('m_001')));

        GmailSendService.EmailRequest r = new GmailSendService.EmailRequest();
        r.toAddress = 'recipient@example.com';
        r.subject = 'Test Subject';
        r.bodyText = 'Hello from test';
        r.fromAddress = 'sender@example.com';

        Test.startTest();
        GmailSendService.EmailResponse resp = GmailSendService.sendEmailSync(r);
        Test.stopTest();

        System.assertEquals(true, resp.success, 'Expected success');
        System.assertEquals('m_001', resp.messageId, 'Message id mismatch');
        System.assertEquals(null, resp.errorMessage, 'No error expected');
    }

    @IsTest
    static void sendEmailSync_httpError() {
        Test.setMock(HttpCalloutMock.class, new MockGmailSendResponse(401, '{"error":"unauthorized"}'));

        GmailSendService.EmailRequest r = new GmailSendService.EmailRequest();
        r.toAddress = 'recipient@example.com';
        r.subject = 'Test Subject';
        r.bodyText = 'Body';

        Test.startTest();
        GmailSendService.EmailResponse resp = GmailSendService.sendEmailSync(r);
        Test.stopTest();

        System.assertEquals(false, resp.success, 'Expected failure');
        System.assert(resp.errorMessage != null && resp.errorMessage.startsWith('HTTP 401'), 'Should capture HTTP error');
    }

    @IsTest
    static void sendEmailInvocable_bulk() {
        Test.setMock(HttpCalloutMock.class, new MockGmailSendResponse(200, buildGmailSendResponse('m_bulk')));

        List<GmailSendService.EmailRequest> inputs = new List<GmailSendService.EmailRequest>();
        for (Integer i = 0; i < 3; i++) {
            GmailSendService.EmailRequest r = new GmailSendService.EmailRequest();
            r.toAddress = 'user' + i + '@example.com';
            r.subject = 'S' + i;
            r.bodyText = 'B' + i;
            inputs.add(r);
        }

        Test.startTest();
        List<GmailSendService.EmailResponse> results = GmailSendService.sendEmailInvocable(inputs);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Expect one result per input');
        for (GmailSendService.EmailResponse res : results) {
            System.assertEquals(true, res.success, 'Each should be success');
            System.assertEquals('m_bulk', res.messageId, 'Mocked id for all');
        }
    }

    @IsTest
    static void enqueueSend_queueable() {
        Test.setMock(HttpCalloutMock.class, new MockGmailSendResponse(200, buildGmailSendResponse('m_q')));

        GmailSendService.EmailRequest r = new GmailSendService.EmailRequest();
        r.toAddress = 'recipient@example.com';
        r.subject = 'Queued';
        r.bodyText = 'Queued body';

        Test.startTest();
        Id jobId = GmailSendService.enqueueSend(r);
        System.assertNotEquals(null, jobId, 'Should enqueue a job');
        Test.stopTest();
        // After stopTest, the queueable runs and mock provides success. No exception means pass.
    }

    @IsTest
    static void sendEmailSync_validations() {
        // Null request
        GmailSendService.EmailResponse resp = GmailSendService.sendEmailSync(null);
        System.assertEquals(false, resp.success);
        System.assertEquals('Request is null', resp.errorMessage);

        // Missing to
        GmailSendService.EmailRequest r1 = new GmailSendService.EmailRequest();
        r1.subject = 'S';
        r1.bodyText = 'B';
        resp = GmailSendService.sendEmailSync(r1);
        System.assertEquals(false, resp.success);
        System.assertEquals('toAddress is required', resp.errorMessage);

        // Missing subject
        GmailSendService.EmailRequest r2 = new GmailSendService.EmailRequest();
        r2.toAddress = 'x@example.com';
        r2.bodyText = 'B';
        resp = GmailSendService.sendEmailSync(r2);
        System.assertEquals(false, resp.success);
        System.assertEquals('subject is required', resp.errorMessage);

        // Missing body
        GmailSendService.EmailRequest r3 = new GmailSendService.EmailRequest();
        r3.toAddress = 'x@example.com';
        r3.subject = 'S';
        resp = GmailSendService.sendEmailSync(r3);
        System.assertEquals(false, resp.success);
        System.assertEquals('bodyText is required', resp.errorMessage);
    }
}
