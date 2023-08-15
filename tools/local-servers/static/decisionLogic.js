function scoreAd(
  adMetadata, bid, auctionConfig, trustedScoringSignals, browserSignals) {
  return {desirability: bid, allowComponentAuction: false};
}

function reportResult(auctionConfig, browserSignals) {
  sendReportTo('https://bidding-auction-server.example.com/static/seller_result');
}
