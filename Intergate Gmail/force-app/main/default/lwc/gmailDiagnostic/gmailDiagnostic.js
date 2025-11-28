import { LightningElement, track } from 'lwc';
import diagnoseNamedCredential from '@salesforce/apex/GmailNamedCredentialDiagnostic.diagnose';

export default class GmailDiagnostic extends LightningElement {
    @track diagnosticResult = null;
    @track isLoading = false;
    @track showSuggestions = false;

    handleDiagnose() {
        this.isLoading = true;
        this.diagnosticResult = null;
        
        diagnoseNamedCredential()
            .then(result => {
                this.diagnosticResult = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.diagnosticResult = {
                    success: false,
                    statusMessage: 'Error occurred during diagnosis',
                    detailedMessage: 'Failed to retrieve diagnostic information: ' + (error.body?.message || error.message || JSON.stringify(error)),
                    suggestions: ['Please check the Salesforce logs for more details']
                };
                this.isLoading = false;
            });
    }

    toggleSuggestions() {
        this.showSuggestions = !this.showSuggestions;
    }

    get hasSuggestions() {
        return this.diagnosticResult && this.diagnosticResult.suggestions && this.diagnosticResult.suggestions.length > 0;
    }

    get isSuccess() {
        return this.diagnosticResult && this.diagnosticResult.success;
    }

    get isError() {
        return this.diagnosticResult && !this.diagnosticResult.success;
    }

    get suggestionLabel() {
        return this.showSuggestions ? "Hide Suggestions" : "Show Suggestions";
    }
}
