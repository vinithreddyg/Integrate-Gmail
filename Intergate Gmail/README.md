# Gmail Integration via Salesforce Named Credential (Google_Gmail_NC)

This repo includes Apex services and tests to send emails through the Gmail API using a Salesforce Named Credential.

Quick Setup Checklist
- [ ] Google Cloud: Create/select project
- [ ] Enable Gmail API
- [ ] Configure OAuth consent screen (External or Internal)
- [ ] Create OAuth Client ID (Web application)
- [ ] Salesforce: Create Auth Provider (Google) and copy Callback URL
- [ ] Google Cloud: Add Salesforce Callback URL to Authorized redirect URIs
- [ ] Salesforce: Create Named Credential (or External Credential + Named Credential)
- [ ] Authenticate/Authorize the Named Credential
- [ ] Deploy LWC sendGmail and add it to a page
- [ ] Test end-to-end and verify Gmail message created

Key components:
- Named Credential: Google_Gmail_NC (configured in Setup)
- Apex service for sending: GmailSendService (Invocable + Queueable)
- Verification utility: GmailNamedCredentialChecker
- Unit tests: GmailSendServiceTest, GmailNamedCredentialCheckerTest

Prerequisites
- A Google Cloud project with Gmail API enabled
- OAuth 2.0 Web Application credentials (Client ID, Client Secret)
- Valid redirect URI for Salesforce Auth Provider:
  - Production: https://login.salesforce.com/services/authcallback/Google
  - Sandbox: https://test.salesforce.com/services/authcallback/Google

Salesforce Setup

1) Create Google Auth Provider
- Setup → Identity → Auth. Providers → New
  - Provider Type: Google (or OpenID Connect with Google endpoints)
  - Name: Google (or GoogleGmail)
  - Consumer Key: [Google Client ID]
  - Consumer Secret: [Google Client Secret]
  - Authorize Endpoint URL: https://accounts.google.com/o/oauth2/v2/auth
  - Token Endpoint URL: https://oauth2.googleapis.com/token
  - User Info Endpoint URL: https://openidconnect.googleapis.com/v1/userinfo
  - Default Scopes: openid email profile https://www.googleapis.com/auth/gmail.send
  - Send client credentials in header: Enabled
- Save and copy the Callback URL, then add it to the Google OAuth client’s “Authorized redirect URIs”.

2) Create Named Credential: Google_Gmail_NC
- Setup → Security → Named Credentials → New
- Label: Google_Gmail_NC
- Name (API Name): Google_Gmail_NC
- URL: https://gmail.googleapis.com/
- Identity Type:
  - Per User: each Salesforce user authorizes their own Gmail
  - Named Principal: one shared Gmail account (org-approved)
- Authentication Protocol: OAuth 2.0
- Auth Provider: select the Google provider created above
- Scope: https://www.googleapis.com/auth/gmail.send openid email profile
- Save, then click Authenticate/Authorize to grant consent
  - If Per User, each user authorizes once on first use

3) Deploy/Push Metadata
- Ensure these Apex classes are deployed:
  - force-app/main/default/classes/GmailSendService.cls
  - force-app/main/default/classes/GmailNamedCredentialChecker.cls
  - force-app/main/default/classes/GmailSendServiceTest.cls
  - force-app/main/default/classes/GmailNamedCredentialCheckerTest.cls

How to Verify the Named Credential

Option A: Anonymous Apex sanity check (admin)
- Execute in Dev Console → Execute Anonymous:
  GmailNamedCredentialChecker.CheckResult res = GmailNamedCredentialChecker.checkProfile();
  // Inspect res.success (expected true), res.emailAddress, res.statusCode=200

Option B: Unit tests
- Run tests: GmailNamedCredentialCheckerTest
  - These use HttpCalloutMock and validate logical handling, not live callouts.

How to Send Email

1) From LWC (sendGmail)
- Deploy the provided LWC: force-app/main/default/lwc/sendGmail
- Add it to an App/Home page in the Lightning App Builder (or Experience page)
- Enter To, Subject, Body and click “Send (Sync)” or “Send (Async)”
- On first use (Per User), Salesforce prompts for Google consent via the Named Credential

2) From Flow (Invocable)
- Action: Apex → Send Gmail Email
- Inputs:
  - toAddress (required)
  - subject (required)
  - bodyText (required)
  - fromAddress (optional; Gmail will default to the authorized account)
- Output fields:
  - success (Boolean), messageId (String), errorMessage (String)

2) From Apex (synchronous)
- Example:
  GmailSendService.EmailRequest r = new GmailSendService.EmailRequest();
  r.toAddress = 'recipient@example.com';
  r.subject = 'Hello from Salesforce';
  r.bodyText = 'This was sent via Gmail API.';
  GmailSendService.EmailResponse resp = GmailSendService.sendEmailSync(r);
  // Check resp.success, resp.messageId, resp.errorMessage

3) From Apex (asynchronous)
- Example:
  GmailSendService.EmailRequest r = new GmailSendService.EmailRequest();
  r.toAddress = 'recipient@example.com';
  r.subject = 'Queued Mail';
  r.bodyText = 'Sent via Queueable.';
  Id jobId = GmailSendService.enqueueSend(r);

Security and Governance Notes
- Do not hardcode client secrets. Keep them only in the Auth Provider record.
- Respect org policies if using a shared account (Named Principal).
- The Apex classes use with sharing and follow early returns and exception handling.
- For user mode queries/DML in future extensions, use Database methods and USER_MODE where appropriate.
- No hard-coded IDs or URLs beyond the Gmail API base and endpoints.

Troubleshooting
- 401/403 errors:
  - Ensure the Named Credential is Authorized and scope includes gmail.send
  - Re-authorize if token expired or revoked
  - If on Google Workspace, get the OAuth app and scope approved by the admin
- Redirect URI mismatch:
  - Update Google OAuth client’s Authorized redirect URIs to match the Salesforce Auth Provider Callback URL
- Endpoint errors:
  - Verify endpoint is callout:Google_Gmail_NC/gmail/v1/users/me/messages/send
- Base64 encoding:
  - Gmail requires base64url for the "raw" payload (handled in GmailSendService.base64UrlEncode)

RFC 2822 Message Format (what we build)
- Headers: From (optional), To, Subject, MIME-Version, Content-Type
- Blank line, then message body (text/plain UTF-8)
- Newlines: \r\n

Files in this repo
- force-app/main/default/classes/GmailSendService.cls
- force-app/main/default/classes/GmailNamedCredentialChecker.cls
- force-app/main/default/classes/GmailSendServiceTest.cls
- force-app/main/default/classes/GmailNamedCredentialCheckerTest.cls
- force-app/main/default/lwc/sendGmail/sendGmail.html
- force-app/main/default/lwc/sendGmail/sendGmail.js
- force-app/main/default/lwc/sendGmail/sendGmail.js-meta.xml

Notes
- For Per User credentials, each user must authorize once. Provide instructions or a quick-start Flow that triggers authorization on first send.
- If using enhanced External Credentials model, map the principal and OAuth settings analogously; Named Credential endpoint usage remains callout:Your_NC_Name/...
