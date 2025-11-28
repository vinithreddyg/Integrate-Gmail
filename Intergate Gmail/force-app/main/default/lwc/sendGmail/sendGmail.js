import { LightningElement } from 'lwc';
import sendEmailAura from '@salesforce/apex/GmailSendService.sendEmailAura';

export default class SendGmail extends LightningElement {
  to = '';
  subject = '';
  body = '';
  message = '';

  toChange(event) {
    this.to = event.target.value;
  }

  subjectChange(event) {
    this.subject = event.target.value;
  }

  bodyChange(event) {
    this.body = event.target.value;
  }

  send() {
    this.message = 'Sending...';
    sendEmailAura({ toAddress: this.to, subject: this.subject, bodyText: this.body })
      .then(res => {
        if (res.success) {
          this.message = 'Sent successfully';
        } else {
          // Provide more specific error messages for common issues
          if (res.errorMessage && (res.errorMessage.includes('named credential') || res.errorMessage.includes('callout'))) {
            this.message = 'Named Credential Error: ' + res.errorMessage;
          } else if (res.errorMessage && (res.errorMessage.includes('401') || res.errorMessage.includes('403'))) {
            this.message = 'Authorization Error: ' + res.errorMessage;
          } else {
            this.message = 'Error: ' + res.errorMessage;
          }
        }
      })
      .catch(err => {
        // Handle general JS errors
        if (err?.body?.message) {
          this.message = 'Error: ' + err.body.message;
        } else if (err?.message) {
          this.message = 'Error: ' + err.message;
        } else {
          this.message = 'Error: ' + JSON.stringify(err);
        }
      });
  }
}
