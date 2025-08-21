// utils/cost_calculator.dart (計算加上移動成本後的價格)

import 'package:price_compare_app/services/distance_service.dart' show TransportMode;

class CostCalculator {
  /// 计算总成本：商品价格 + 交通移动成本（里程成本 + 时间成本）+ 停车/票价
  ///
  /// ✅ 向下相容：保留原本所有参数与默认值
  /// ✅ 新增可选参数：
  ///   - [durationInMin]：单程实际时间(分钟)。若不传，会用平均速度估算，旧逻辑不受影响。
  ///   - [roundTrip]：是否计算往返（去+回），默认 false。
  ///   - [tolls]：过路费（元），默认 0。
  static double calculateTotalCost({
    // —— 原本必填 —— 
    required double distanceInKm,
    required double basePrice,

    // —— 原本参数（保留默认值与命名）——
    TransportMode mode = TransportMode.driving,
    double fuelPricePerKm    = 2.5,   // 开车：油钱+折旧 (元/km)
    double cyclingPricePerKm = 0.1,   // 自行车维护成本 (元/km)
    double walkingPricePerKm = 0.0,   // 走路无需里程成本
    double transitPerKmFare  = 1.0,   // 预留：大众运输里程票价 (元/km)
    double transitBaseFare   = 30.0,  // 预留：大众运输基础票价 (元)
    double timeValuePerMin   = 0.5,   // 时间价值 (元/分钟)
    bool   includeParking    = true,
    double parkingFee        = 30.0,  // 停车费 (元)

    // —— 新增但可不传（不会影响旧调用）——
    double? durationInMin,            // 单程「实际」分钟；不传则用平均速度估
    bool   roundTrip = false,         // 是否往返
    double tolls = 0.0,               // 过路费
  }) {
    // 1) 估算或使用实际“单程时间(分钟)”
    //    —— 若你有从 Distance Matrix 拿到 duration，就传进来更准；
    //       没传则用平均速度估（保持旧行为）
    final avgSpeedsKmPerMin = {
      TransportMode.driving: 40.0 / 60.0,   // 40 km/h
      TransportMode.cycling: 15.0 / 60.0,   // 15 km/h
      TransportMode.walking:  5.0 / 60.0,   // 5  km/h
      // 若未来 enum 扩充 transit，再在此加入
    };
    final estDurationSingleMin =
        distanceInKm / (avgSpeedsKmPerMin[mode] ?? (30.0 / 60.0));
    final singleTripMin = durationInMin ?? estDurationSingleMin;

    // 若为往返，把距离与时间都乘 2（不影响旧调用，默认 false）
    final factor = roundTrip ? 2.0 : 1.0;
    final effDistanceKm = distanceInKm * factor;
    final effMinutes    = singleTripMin * factor;

    // 2) 里程“金钱”成本（不同交通模式的每公里成本）
    final perKmCost = switch (mode) {
      TransportMode.driving => fuelPricePerKm,
      TransportMode.cycling => cyclingPricePerKm,
      TransportMode.walking => walkingPricePerKm,
      // 若未来加入 TransitMode.transit：这里就回传 0，由票价独立计算
    };
    final distanceCost = effDistanceKm * perKmCost;

    // 3) 票价/停车/过路（目前你的 enum 没有 transit，因此先不加票价）
    //    —— 保留参数以便未来扩充，不会影响现状
    double fare = 0.0;
    // if (mode == TransportMode.transit) {
    //   fare = transitBaseFare + transitPerKmFare * effDistanceKm;
    // }
    final parking = (mode == TransportMode.driving && includeParking) ? parkingFee : 0.0;

    // 4) 时间成本 = 每分钟时间价值 × 有效分钟
    final timeCost = timeValuePerMin * effMinutes;

    // 5) 组合移动成本（里程 + 时间 + 停车 + 票价 + 过路费）
    final transportCost = distanceCost + timeCost + parking + fare + tolls;

    // 6) 总成本 = 商品价格 + 移动成本
    return basePrice + transportCost;
  }
}


