// utils/cost_calculator.dart (算成本)

class CostCalculator {
  static double calculateTotalCost({
    required double distanceInKm,
    required double basePrice,
    double transportCostPerKm = 5, // 運費：5元/公里
    double fatigueCostPerKm = 10,   // 累勞表：10元/公里
    double parkingFee = 20,         // 停車費
    double weatherMultiplier = 1.0, // 天氣加成
  }) {
    double transportCost = distanceInKm * transportCostPerKm;
    double fatigueCost = distanceInKm * fatigueCostPerKm;
    double totalCost = (basePrice + transportCost + fatigueCost + parkingFee) * weatherMultiplier;
    return totalCost;
  }
}
