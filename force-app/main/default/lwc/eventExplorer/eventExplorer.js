import { LightningElement, track } from 'lwc';
import searchEvents from '@salesforce/apex/EevEventExplorerController.searchEvents';
import getEventDetail from '@salesforce/apex/EevEventExplorerController.getEventDetail';

export default class EventExplorer extends LightningElement {
    // Filter properties
    @track searchTerm = '';
    @track selectedCategory = '';
    @track selectedCity = '';
    @track fromDate = null;
    @track toDate = null;

    // View state
    @track eventCards = [];
    @track selectedEventId = null;
    @track selectedEventDetail = null;
    @track isLoading = true;
    @track errorMessage = null;

    // Concurrency guard
    requestSequence = 0;
    debounceTimeout = null;

    connectedCallback() {
        this.fetchEvents();
    }

    // ─── Filter Options ─────────────────────────────────────────────────────────

    get categoryOptions() {
        return [
            { label: 'All Categories', value: '' },
            { label: 'Technology', value: 'Technology' },
            { label: 'Music', value: 'Music' },
            { label: 'Sports', value: 'Sports' },
            { label: 'Arts', value: 'Arts' },
            { label: 'Business', value: 'Business' },
            { label: 'Community', value: 'Community' }
        ];
    }

    get cityOptions() {
        return [
            { label: 'All Cities', value: '' },
            { label: 'Bengaluru', value: 'Bengaluru' },
            { label: 'Mumbai', value: 'Mumbai' },
            { label: 'Delhi', value: 'Delhi' },
            { label: 'Hyderabad', value: 'Hyderabad' }
        ];
    }

    // ─── Filter Change Handlers ─────────────────────────────────────────────────

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if (this.debounceTimeout) {
            clearTimeout(this.debounceTimeout);
        }
        this.debounceTimeout = setTimeout(() => {
            this.fetchEvents();
        }, 300);
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.fetchEvents();
    }

    handleCityChange(event) {
        this.selectedCity = event.detail.value;
        this.fetchEvents();
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.fetchEvents();
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.fetchEvents();
    }

    handleClearFilters() {
        this.searchTerm = '';
        this.selectedCategory = '';
        this.selectedCity = '';
        this.fromDate = null;
        this.toDate = null;
        this.fetchEvents();
    }

    handleTryAgain() {
        this.fetchEvents();
    }

    // ─── Apex Data Fetching ─────────────────────────────────────────────────────

    fetchEvents() {
        this.isLoading = true;
        this.errorMessage = null;
        const currentReqId = ++this.requestSequence;

        const params = {
            searchTerm: this.searchTerm ? this.searchTerm.trim() : null,
            category: this.selectedCategory ? this.selectedCategory : null,
            city: this.selectedCity ? this.selectedCity : null,
            fromDate: this.fromDate ? this.fromDate : null,
            toDate: this.toDate ? this.toDate : null
        };

        searchEvents(params)
            .then((data) => {
                // Ignore stale out-of-order responses
                if (currentReqId !== this.requestSequence) {
                    return;
                }
                this.eventCards = data.map((item) => this.formatEventCard(item));
                this.isLoading = false;

                // Refresh open detail if still valid
                if (this.selectedEventId) {
                    const stillExists = this.eventCards.some((c) => c.id === this.selectedEventId);
                    if (!stillExists) {
                        this.selectedEventId = null;
                        this.selectedEventDetail = null;
                    }
                }
            })
            .catch((error) => {
                if (currentReqId !== this.requestSequence) {
                    return;
                }
                this.isLoading = false;
                this.errorMessage = this.extractErrorMessage(error);
            });
    }

    handleSelectEvent(event) {
        const eventId = event.currentTarget.dataset.id;
        this.selectedEventId = eventId;
        this.loadEventDetail(eventId);
    }

    handleCardKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleSelectEvent(event);
        }
    }

    handleCloseDetail() {
        this.selectedEventId = null;
        this.selectedEventDetail = null;
        this.updateCardSelectionHighlight();
    }

    loadEventDetail(eventId) {
        getEventDetail({ eventId })
            .then((data) => {
                if (data) {
                    this.selectedEventDetail = {
                        ...data,
                        tiers: data.tiers ? data.tiers.map((t) => this.formatTierRow(t)) : []
                    };
                } else {
                    this.selectedEventDetail = null;
                }
                this.updateCardSelectionHighlight();
            })
            .catch((error) => {
                this.errorMessage = this.extractErrorMessage(error);
            });
    }

    // ─── Formatters & State Helpers ─────────────────────────────────────────────

    formatEventCard(card) {
        const isSelected = card.id === this.selectedEventId;
        const formattedDate = card.startAt ? new Intl.DateTimeFormat('en-US', {
            weekday: 'short', month: 'short', day: 'numeric',
            hour: 'numeric', minute: '2-digit', hour12: true
        }).format(new Date(card.startAt)) : 'Date TBA';

        const venueDisplay = card.venueName
            ? (card.city ? `${card.venueName}, ${card.city}` : card.venueName)
            : (card.city || 'Location TBA');

        const isSoldOut = card.priceFrom === null || card.priceFrom === undefined;
        const formattedPrice = !isSoldOut ? Number(card.priceFrom).toLocaleString() : '';

        return {
            ...card,
            formattedDate,
            venueDisplay,
            isSoldOut,
            formattedPrice,
            ariaLabel: `${card.name}, ${formattedDate}, ${venueDisplay}`,
            cardClass: `event-card slds-box slds-box_link ${isSelected ? 'selected-card' : ''}`
        };
    }

    formatTierRow(tier) {
        let statusBadge = false;
        let badgeText = '';
        let badgeClass = '';

        if (!tier.isSellable) {
            statusBadge = true;
            if (tier.available === 0) {
                badgeText = 'Sold out';
                badgeClass = 'slds-badge slds-theme_error slds-m-left_x-small';
            } else {
                badgeText = 'Not on sale';
                badgeClass = 'slds-badge slds-theme_warning slds-m-left_x-small';
            }
        }

        return {
            ...tier,
            statusBadge,
            badgeText,
            badgeClass
        };
    }

    updateCardSelectionHighlight() {
        this.eventCards = this.eventCards.map((c) => ({
            ...c,
            cardClass: `event-card slds-box slds-box_link ${c.id === this.selectedEventId ? 'selected-card' : ''}`
        }));
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.eventCards.length === 0;
    }

    get resultCountLabel() {
        const count = this.eventCards.length;
        return `${count} ${count === 1 ? 'event' : 'events'} found`;
    }

    get cardsColumnClass() {
        return this.selectedEventDetail
            ? 'slds-col slds-size_1-of-1 slds-large-size_7-of-12'
            : 'slds-col slds-size_1-of-1';
    }

    extractErrorMessage(error) {
        if (!error) return 'An unexpected error occurred.';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unable to load events. Please try again.';
    }
}

