import { Component, Input } from '@angular/core';
import { AuctionStatus } from '../../core/models/auctions.model';

@Component({
  selector: 'app-auction-status-badge', standalone: true,
  template: `<span class="auction-status status-{{ status.toLowerCase() }}">{{ status }}</span>`,
})
export class AuctionStatusBadgeComponent {
  @Input({ required: true }) status!: AuctionStatus;
}
