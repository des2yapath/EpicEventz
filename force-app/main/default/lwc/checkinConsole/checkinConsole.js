import { LightningElement, track, wire } from 'lwc';
import processCheckin from '@salesforce/apex/EevCheckinController.processCheckin';
import getRecentPasses from '@salesforce/apex/EevCheckinController.getRecentPasses';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CheckinConsole extends LightningElement {
    @track tokenInput = '';
    @track isProcessing = false;
    @track lastResult = null;
    @track recentPasses = [];

    wiredPassesResult;

    @wire(getRecentPasses)
    wiredPasses(result) {
        this.wiredPassesResult = result;
        if (result.data) {
            this.recentPasses = result.data.map(p => ({
                ...p,
                badgeClass: p.status === 'Checked-In' 
                    ? 'slds-badge slds-theme_success' 
                    : (p.status === 'Cancelled' ? 'slds-badge slds-theme_error' : 'slds-badge')
            }));
        } else if (result.error) {
            this.recentPasses = [];
        }
    }

    get hasRecentPasses() {
        return this.recentPasses && this.recentPasses.length > 0;
    }

    handleTokenChange(event) {
        this.tokenInput = event.target.value;
    }

    handleLoadToken(event) {
        const token = event.currentTarget.dataset.token;
        if (token) {
            this.tokenInput = token;
        }
    }

    handleClear() {
        this.tokenInput = '';
        this.lastResult = null;
    }

    async handleCheckin() {
        if (!this.tokenInput || !this.tokenInput.trim()) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Token Required',
                message: 'Please enter or scan a QR token before checking in.',
                variant: 'warning'
            }));
            return;
        }

        this.isProcessing = true;
        this.lastResult = null;

        try {
            const result = await processCheckin({ token: this.tokenInput.trim() });
            this.lastResult = result;

            if (result.isSuccess) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Admitted',
                    message: result.message,
                    variant: 'success'
                }));
                this.tokenInput = '';
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Check-In Refused',
                    message: result.message,
                    variant: 'error'
                }));
            }
            await refreshApex(this.wiredPassesResult);
        } catch (error) {
            this.lastResult = {
                isSuccess: false,
                message: error.body ? error.body.message : error.message
            };
        } finally {
            this.isProcessing = false;
        }
    }

    async refreshList() {
        await refreshApex(this.wiredPassesResult);
    }
}

