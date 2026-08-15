/**
 * Calculate distance between two coordinates in Kilometers (Haversine Formula)
 */
function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Check if a point is within a radius of a safe zone center
 */
function isWithinRadius(lat1, lon1, lat2, lon2, radiusMeters) {
  const distanceKm = calculateDistanceKm(lat1, lon1, lat2, lon2);
  return distanceKm * 1000 <= radiusMeters;
}

module.exports = { calculateDistanceKm, isWithinRadius };
