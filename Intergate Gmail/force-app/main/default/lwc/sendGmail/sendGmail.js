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
        this.message = 'Sent successfully';
      })
      .catch(err => {
        this.message = 'Error: ' + (err?.body?.message || JSON.stringify(err));
      });
  }
}
