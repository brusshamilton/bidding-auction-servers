function generateBid(
  interestGroup, auctionSignals, perBuyerSignals, trustedBiddingSignals,
  browserSignals, directFromSellerSignals) {

  return {ad: {},
          adCost: 1,
          bid: 1,
          render: 'https://bidding-auction-server.example.com/static/fake_ad.html',
          allowComponentAuction: false,
          modelingSignals: 123};
}

function reportWin(auctionSignals, perBuyerSignals, sellerSignals,
browserSignals, directFromSellerSignals) {
  sendReportTo('https://bidding-auction-server.example.com/static/bidding_winner');
}
