# Deployment Instructions for Gmail Integration Fixes

## Prerequisites
- Salesforce CLI (sf) installed and authenticated
- Dev Hub org configured (if using scratch orgs)
- Source tracking enabled in your project

## Deployment Steps

### 1. Deploy to Scratch Org or Sandbox
```bash
sf deploy metadata --source-dir force-app --target-org your-org-alias
```

### 2. Deploy to Production (if needed)
```bash
sf deploy metadata --source-dir force-app --target-org production-org-alias
```

### 3. Run Tests
After deployment, run the unit tests to ensure everything works correctly:
```bash
sf run test --test-names GmailSendServiceTest,GmailNamedCredentialCheckerTest,GmailNamedCredentialValidatorTest
```

## Files Deployed

### Apex Classes:
- `force-app/main/default/classes/GmailSendService.cls` - Enhanced error handling
- `force-app/main/default/classes/GmailNamedCredentialDiagnostic.cls` - Improved diagnostics
- `force-app/main/default/classes/GmailNamedCredentialValidator.cls` - New validation utility
- `force-app/main/default/classes/GmailNamedCredentialValidatorTest.cls` - Unit tests

### Metadata Files:
- `force-app/main/default/classes/GmailNamedCredentialValidator.cls-meta.xml`
- `force-app/main/default/classes/GmailNamedCredentialValidatorTest.cls-meta.xml`

### LWC Components:
- `force-app/main/default/lwc/gmailDiagnostic/gmailDiagnostic.js` - Enhanced error handling
- `force-app/main/default/lwc/sendGmail/sendGmail.js` - Better error messages

### Documentation:
- `README.md` - Updated troubleshooting section

## Verification Steps

1. After deployment, navigate to Setup → Security → Named Credentials
2. Verify that "Google_Gmail_NC" exists and is properly configured
3. Test the diagnostic utility by using the "Gmail Named Credential Diagnostic" LWC component
4. Test sending an email through the "sendGmail" LWC component

## Troubleshooting

If you still encounter issues after deployment:
1. Check that the named credential "Google_Gmail_NC" exists in Setup
2. Verify that the OAuth scopes include "https://www.googleapis.com/auth/gmail.send"
3. Ensure the named credential is properly authorized
4. Confirm the endpoint URL is set to "https://gmail.googleapis.com/"
