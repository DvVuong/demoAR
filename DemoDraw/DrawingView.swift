//
//  DrawingView.swift
//  DemoDraw
//
//  Created by VuongDv on 18/03/2025.
//

import UIKit
import AVFoundation

// Enum để phân biệt các loại màu
enum ColorType: Int {
  case none = 0
  case primary = 1   // Màu 1 (ví dụ: xanh lam)
  case secondary = 2 // Màu 2 (ví dụ: đỏ)
}

// Cấu trúc để lưu trữ thông tin về pixel
struct PixelInfo {
  var colorType: ColorType
  var position: CGPoint
  
  init(colorType: ColorType, x: Int, y: Int) {
    self.colorType = colorType
    self.position = CGPoint(x: x, y: y)
  }
}

class DrawingView: UIView {
  
  // Hình ảnh mẫu (template) với các vùng màu
  var templateImage: UIImage?
  
  // Lưu kích thước thật của hình ảnh
  private var imageWidth: Int = 0
  private var imageHeight: Int = 0
  
  // Lưu trữ tọa độ các pixel có màu cần kiểm tra
  private var coloredPoints: Set<String> = []
  
  // Lưu trữ tọa độ các điểm user đã vẽ
  private var userDrawnPoints: Set<String> = []
  
  // Đường vẽ hiện tại
  private var currentLine: [CGPoint] = []
  
  // Lịch sử các đường vẽ
  private var finishedLines: [[CGPoint]] = []
  // Thêm mảng để lưu màu cho mỗi đường vẽ đã hoàn thành
  private var finishedLinesColors: [UIColor] = []
  
  // Thêm biến để theo dõi các lớp vẽ (mỗi khi chuyển ảnh mới tạo một lớp mới)
  private var drawingLayers: [DrawingLayer] = []
  // Lớp vẽ hiện tại
  private var currentLayerIndex: Int = 0
  
  // Màu của ngưỡng phát hiện và màu vẽ
  var targetColor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8) = (100, 100, 150, 200) // Xanh lam mặc định
  var strokeColor: UIColor = .red
  var strokeWidth: CGFloat = 5.0
  
  // Các thuộc tính vẽ nâng cao
  var strokeCapStyle: CGLineCap = .round
  var strokeJoinStyle: CGLineJoin = .round
  var brushOpacity: CGFloat = 1.0
  var useSmoothBrush: Bool = true
  var brushPressureSensitivity: CGFloat = 0.5 // 0.0 - 1.0
  
  // Callback khi người dùng vẽ ra ngoài vùng màu
  var onDrawOutsideColoredArea: ((CGPoint) -> Void)?
  
  // Callback khi người dùng vẽ vào đúng vùng màu
  var onDrawInsideColoredArea: ((CGPoint) -> Void)?
  
  // Callback khi cập nhật tỷ lệ phần trăm vùng đã tô
  var onColorPercentageUpdated: ((Double) -> Void)?
  
  // Callback khi cần cập nhật thanh progress
  var onProgressUpdate: ((Float, Bool) -> Void)?
  
  // Lưu trữ imageRect để giữ nhất quán giữa các phương thức
  private var imageRect: CGRect = .zero
  
  // Thống kê
  private var insidePointsCount: Int = 0
  private var outsidePointsCount: Int = 0
  
  // Thêm cấu trúc để quản lý các lớp vẽ
  struct DrawingLayer {
    var lines: [[CGPoint]]
    var colors: [UIColor]
    var associatedImageName: String // Tên ảnh mẫu liên kết với lớp này
    
    init(imageName: String = "") {
      lines = []
      colors = []
      associatedImageName = imageName
    }
  }
  
  // Thêm biến để điều chỉnh khoảng cách tối thiểu giữa các điểm vẽ
  var minDistanceBetweenDrawnPoints: Int = 2 // Mặc định cao hơn để tránh vẽ đè
  
  // MARK: - Initialization
  
  init(frame: CGRect, templateImage: UIImage?, imageName: String = "rabit1") {
    self.templateImage = templateImage
    super.init(frame: frame)
    backgroundColor = .white
    
    // Tạo lớp vẽ đầu tiên
    drawingLayers.append(DrawingLayer(imageName: imageName))
    currentLayerIndex = 0
    
    if let templateImage = templateImage {
      updateImageRect()
      analyzeImage(templateImage)
    }
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .white
  }
  
  // MARK: - Image Analysis
  
  private func updateImageRect() {
    if let templateImage = templateImage {
      imageRect = AVMakeRect(aspectRatio: templateImage.size, insideRect: bounds)
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    updateImageRect()
  }
  
  // Kiểm tra xem một pixel có phải là màu cần tìm hay không
  private func isTargetColor(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> Bool {
    // Giá trị mặc định khá nghiêm ngặt, sửa thành đơn giản hơn
    
    // Kiểm tra màu xanh - xem nếu màu xanh lam chiếm ưu thế
    // Chuyển đổi UInt8 sang Int để tránh tràn số
    let rInt = Int(r)
    let gInt = Int(g)
    let bInt = Int(b)
    
    if bInt > gInt + 30 && bInt > rInt + 30 && a > 100 {
      return true
    }
    
    // Màu xanh theo cách khác - thông thường là các màu xanh lam
    // Đây là một cách kiểm tra lỏng lẻo hơn
    if b > 180 && r < 150 && g < 150 && a > 100 {
      return true
    }
    
    // Ngưỡng tùy chỉnh từ targetColor
    if b > targetColor.b && r < targetColor.r && g < targetColor.g && a > targetColor.a {
      return true
    }
    
    return false
  }
  
  // Phân tích hình ảnh để tìm các điểm có màu cần kiểm tra
  func analyzeImage(_ image: UIImage) {
    guard let cgImage = image.cgImage else { return }
    
    imageWidth = Int(image.size.width)
    imageHeight = Int(image.size.height)
    
    // Tạo không gian màu và ngữ cảnh để đọc dữ liệu pixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * imageWidth
    let bitsPerComponent = 8
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    
    guard let context = CGContext(data: nil,
                                  width: imageWidth,
                                  height: imageHeight,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo) else { return }
    
    // Vẽ hình ảnh vào ngữ cảnh để có thể truy cập dữ liệu pixel
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
    
    guard let pixelData = context.data else { return }
    
    // Xóa dữ liệu cũ
    coloredPoints.removeAll()
    
    // Biến theo dõi để debug
    var pixelColors: [UIColor] = []
    var maxBlueValue: UInt8 = 0
    var minRedValue: UInt8 = 255
    var minGreenValue: UInt8 = 255
    
    // Duyệt qua từng pixel để tìm màu
    for y in 0..<imageHeight {
      for x in 0..<imageWidth {
        let pixelInfo = Int(bytesPerRow * y + bytesPerPixel * x)
        let r = pixelData.load(fromByteOffset: pixelInfo, as: UInt8.self)
        let g = pixelData.load(fromByteOffset: pixelInfo + 1, as: UInt8.self)
        let b = pixelData.load(fromByteOffset: pixelInfo + 2, as: UInt8.self)
        let a = pixelData.load(fromByteOffset: pixelInfo + 3, as: UInt8.self)
        
        // Cập nhật giá trị max/min cho debug
        maxBlueValue = max(maxBlueValue, b)
        minRedValue = min(minRedValue, r)
        minGreenValue = min(minGreenValue, g)
        
        // Lưu một số mẫu màu để debug
        if pixelColors.count < 10 && a > 100 {
          pixelColors.append(UIColor(red: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: CGFloat(a)/255.0))
        }
        
        // Kiểm tra xem pixel có phải là màu cần tìm không
        if isTargetColor(r: r, g: g, b: b, a: a) {
          // Lưu tọa độ điểm
          let key = "\(x),\(y)"
          coloredPoints.insert(key)
        }
      }
    }
    
    // In thông tin debug
    print("Tìm thấy \(coloredPoints.count) điểm có màu cần kiểm tra")
    print("Thông tin debug:")
    print("Max giá trị Blue: \(maxBlueValue)")
    print("Min giá trị Red: \(minRedValue)")
    print("Min giá trị Green: \(minGreenValue)")
    // Nếu không tìm thấy pixel nào, hãy thử một lần nữa với ngưỡng khác
    if coloredPoints.isEmpty {
      print("Không tìm thấy pixel nào với cài đặt hiện tại. Thử lại với ngưỡng khác...")
      for y in 0..<imageHeight {
        for x in 0..<imageWidth {
          let pixelInfo = Int(bytesPerRow * y + bytesPerPixel * x)
          let r = pixelData.load(fromByteOffset: pixelInfo, as: UInt8.self)
          let g = pixelData.load(fromByteOffset: pixelInfo + 1, as: UInt8.self)
          let b = pixelData.load(fromByteOffset: pixelInfo + 2, as: UInt8.self)
          let a = pixelData.load(fromByteOffset: pixelInfo + 3, as: UInt8.self)
          
          // Ngưỡng linh hoạt hơn (màu xanh lam bất kỳ)
          if b > r && b > g && a > 100 {
            let key = "\(x),\(y)"
            coloredPoints.insert(key)
          }
        }
      }
      print("Tìm thấy \(coloredPoints.count) điểm sau khi áp dụng ngưỡng linh hoạt hơn")
    }
  }
  
  // MARK: - Point Conversion & Check
  
  // Chuyển đổi từ tọa độ view sang tọa độ pixel trong hình ảnh
  private func getPixelCoordinates(from viewPoint: CGPoint) -> (x: Int, y: Int)? {
    guard !imageRect.isEmpty else { return nil }
    
    // Kiểm tra xem điểm có nằm trong khu vực hình ảnh không
    guard imageRect.contains(viewPoint) else { return nil }
    
    // Chuyển đổi từ tọa độ view sang tọa độ hình ảnh (0-1)
    let normalizedX = (viewPoint.x - imageRect.origin.x) / imageRect.width
    let normalizedY = (viewPoint.y - imageRect.origin.y) / imageRect.height
    
    // Chuyển đổi sang tọa độ pixel
    let pixelX = Int(normalizedX * CGFloat(imageWidth))
    let pixelY = Int(normalizedY * CGFloat(imageHeight))
    
    // Kiểm tra giới hạn
    guard pixelX >= 0, pixelX < imageWidth,
          pixelY >= 0, pixelY < imageHeight else {
      return nil
    }
    
    return (pixelX, pixelY)
  }
  
  // Thêm phương thức để kiểm tra xem một điểm có gần các điểm đã vẽ không
  private func isNearExistingPoints(_ pixel: (x: Int, y: Int), threshold: Int? = nil) -> Bool {
    // Nếu tính năng bị vô hiệu hóa (ngưỡng = 0), luôn trả về false
    let actualThreshold = threshold ?? minDistanceBetweenDrawnPoints
    if actualThreshold <= 0 {
      return false // Cho phép vẽ đè nếu người dùng tắt tính năng
    }
    
    // Kiểm tra điểm hiện tại (chính xác)
    let key = "\(pixel.x),\(pixel.y)"
    if userDrawnPoints.contains(key) {
      return true
    }
    
    // Kiểm tra các điểm xung quanh trong phạm vi threshold
    for dx in -actualThreshold...actualThreshold {
      for dy in -actualThreshold...actualThreshold {
        // Chỉ kiểm tra các điểm trong một hình tròn xung quanh điểm hiện tại
        if dx*dx + dy*dy <= actualThreshold*actualThreshold {
          let nearbyKey = "\(pixel.x + dx),\(pixel.y + dy)"
          if userDrawnPoints.contains(nearbyKey) {
            return true
          }
        }
      }
    }
    
    return false
  }
  
  // Kiểm tra một điểm có nằm trong vùng màu không và chỉ đếm nếu là điểm mới
  private func isPointInColoredArea(_ point: CGPoint) -> Bool {
    if let pixel = getPixelCoordinates(from: point) {
      let key = "\(pixel.x),\(pixel.y)"
      
      // Kiểm tra điểm có nằm trong vùng màu không
      let result = coloredPoints.contains(key)
      
      // CHỈ lưu điểm và đếm nếu điểm chưa tồn tại trong userDrawnPoints
      if !userDrawnPoints.contains(key) {
        // Lưu điểm user đã vẽ
        userDrawnPoints.insert(key)
        
        if result {
          insidePointsCount += 1
          print("✅ Điểm (\(pixel.x), \(pixel.y)) nằm TRONG vùng màu cần tô")
          
          // Thông báo đây là điểm trong vùng màu
          onProgressUpdate?(0, true)
        } else {
          outsidePointsCount += 1
          print("❌ Điểm (\(pixel.x), \(pixel.y)) nằm NGOÀI vùng màu cần tô")
          
          // Thông báo đây là điểm ngoài vùng màu
          onProgressUpdate?(0, false)
        }
      } else {
        print("🔄 Điểm (\(pixel.x), \(pixel.y)) đã tồn tại, không tính lại")
      }
      
      return result
    }
    
    return false
  }
  
  // Tính toán tỷ lệ phần trăm vùng đã tô
  private func updateColorPercentage() {
    if coloredPoints.isEmpty {
      onColorPercentageUpdated?(0)
      return
    }
    
    // Đếm số điểm trong vùng màu mà user đã vẽ
    let intersection = coloredPoints.intersection(userDrawnPoints)
    let percentage = (Double(intersection.count) / Double(coloredPoints.count)) * 100.0
    
    print("Đã tô: \(intersection.count)/\(coloredPoints.count) = \(percentage)%")
    print("Thống kê: \(insidePointsCount) điểm TRONG vùng, \(outsidePointsCount) điểm NGOÀI vùng")
    
    onColorPercentageUpdated?(percentage)
    
    // Cập nhật thanh progress tổng thể với tỷ lệ điểm trong/ngoài vùng màu
    if insidePointsCount + outsidePointsCount > 0 {
      // Gửi tỷ lệ để cập nhật progress bar
      // Truyền true để thể hiện rằng đây là cập nhật sau khi hoàn thành một đường vẽ
      onProgressUpdate?(1.0, insidePointsCount > outsidePointsCount)
    }
  }
  
  // MARK: - Touch Handling
  
  // Lưu điểm chạm cuối cùng để tính khoảng cách
  private var lastPoint: CGPoint?
  // Khoảng cách tối thiểu giữa các điểm (quá gần sẽ không thêm)
  private var minDistance: CGFloat = 1.0
  // Khoảng cách tối đa giữa các điểm (quá xa sẽ thêm điểm trung gian)
  private var maxDistance: CGFloat = 15.0
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let location = touch.location(in: self)
    
    // Bỏ kiểm tra isNearExistingPoints để cho phép vẽ đè
    
    // Đặt lại đường hiện tại và lưu điểm đầu tiên
    currentLine = [location]
    lastPoint = location
    
    // Kiểm tra và gọi callback - chỉ gọi nếu điểm chưa được vẽ trước đó
    if let pixel = getPixelCoordinates(from: location) {
      let key = "\(pixel.x),\(pixel.y)"
      if !userDrawnPoints.contains(key) {
        if isPointInColoredArea(location) {
          onDrawInsideColoredArea?(location)
        } else {
          onDrawOutsideColoredArea?(location)
        }
      }
    }
    
    setNeedsDisplay()
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let location = touch.location(in: self)
    
    // Kiểm tra xem điểm có nằm trong vùng hình ảnh không
    guard let pixel = getPixelCoordinates(from: location) else {
      return // Bỏ qua các điểm nằm ngoài vùng hình ảnh
    }
    
    // Bỏ kiểm tra isNearExistingPoints để cho phép vẽ đè
    
    // Tính khoảng cách từ điểm cuối cùng
    guard let lastPoint = lastPoint else {
      self.lastPoint = location
      currentLine.append(location)
      
      // Kiểm tra và gọi callback - chỉ khi điểm chưa được vẽ
      let key = "\(pixel.x),\(pixel.y)"
      if !userDrawnPoints.contains(key) {
        if isPointInColoredArea(location) {
          onDrawInsideColoredArea?(location)
        } else {
          onDrawOutsideColoredArea?(location)
        }
      }
      
      setNeedsDisplay()
      return
    }
    
    let distance = hypot(location.x - lastPoint.x, location.y - lastPoint.y)
    
    // Bỏ qua các điểm quá gần
    if distance < minDistance {
      return
    }
    
    // Luôn thêm điểm mới vào đường vẽ, bất kể có đè lên điểm cũ hay không
    var addedAnyPoint = false
    
    if distance > maxDistance {
      let stepCount = Int(distance / maxDistance) + 1
      for i in 1...stepCount {
        let progress = CGFloat(i) / CGFloat(stepCount)
        let interpolatedX = lastPoint.x + (location.x - lastPoint.x) * progress
        let interpolatedY = lastPoint.y + (location.y - lastPoint.y) * progress
        let interpolatedPoint = CGPoint(x: interpolatedX, y: interpolatedY)
        
        // Kiểm tra xem điểm nội suy có nằm trong vùng hình ảnh không
        guard let interpPixel = getPixelCoordinates(from: interpolatedPoint) else {
          continue // Bỏ qua các điểm nằm ngoài vùng hình ảnh
        }
        
        // Luôn thêm điểm vào đường vẽ
        currentLine.append(interpolatedPoint)
        addedAnyPoint = true
        
        // Kiểm tra và gọi callback - chỉ khi điểm chưa được vẽ
        let key = "\(interpPixel.x),\(interpPixel.y)"
        if !userDrawnPoints.contains(key) {
          if isPointInColoredArea(interpolatedPoint) {
            onDrawInsideColoredArea?(interpolatedPoint)
          } else {
            onDrawOutsideColoredArea?(interpolatedPoint)
          }
        }
      }
    } else {
      // Luôn thêm điểm vào đường vẽ
      currentLine.append(location)
      addedAnyPoint = true
      
      // Kiểm tra và gọi callback - chỉ khi điểm chưa được vẽ
      let key = "\(pixel.x),\(pixel.y)"
      if !userDrawnPoints.contains(key) {
        if isPointInColoredArea(location) {
          onDrawInsideColoredArea?(location)
        } else {
          onDrawOutsideColoredArea?(location)
        }
      }
    }
    
    // Cập nhật điểm cuối cùng và vẽ lại
    if addedAnyPoint {
      self.lastPoint = location
      setNeedsDisplay()
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    // Nếu có điểm chạm cuối cùng, thêm vào đường vẽ
    if let touch = touches.first {
      let location = touch.location(in: self)
      
      // Chỉ thêm nếu khác với điểm cuối cùng
      if let lastPoint = currentLine.last,
          hypot(location.x - lastPoint.x, location.y - lastPoint.y) > minDistance {
        currentLine.append(location)
      }
    }
    
    // Lưu đường vẽ hiện tại vào lịch sử
    if !currentLine.isEmpty {
      finishedLines.append(currentLine)
      finishedLinesColors.append(strokeColor)
      
      // Cập nhật lớp vẽ hiện tại
      if currentLayerIndex < drawingLayers.count {
        drawingLayers[currentLayerIndex].lines = finishedLines
        drawingLayers[currentLayerIndex].colors = finishedLinesColors
      }
      
      currentLine = []
    }
    
    // Đặt lại điểm cuối cùng
    lastPoint = nil
    
    updateColorPercentage()
    setNeedsDisplay()
  }
  
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    // Xử lý tương tự touchesEnded
    touchesEnded(touches, with: event)
  }
  
  // MARK: - Drawing
  
  override func draw(_ rect: CGRect) {
    super.draw(rect)
    
    // Vẽ các lớp cũ trước
    for i in 0..<drawingLayers.count {
      if i != currentLayerIndex { // Không vẽ lớp hiện tại ở đây
        let layer = drawingLayers[i]
        for j in 0..<layer.lines.count {
          drawSmoothLine(layer.lines[j], color: layer.colors[j], in: UIGraphicsGetCurrentContext())
        }
      }
    }
    
    // Vẽ hình ảnh mẫu (với độ mờ)
    if let templateImage = templateImage {
      updateImageRect()
      templateImage.draw(in: imageRect, blendMode: .normal, alpha: 0.8)
    }
    
    // Vẽ với nét mượt mà hơn
    let context = UIGraphicsGetCurrentContext()
    context?.setLineCap(strokeCapStyle)
    context?.setLineJoin(strokeJoinStyle)
    context?.setAlpha(brushOpacity)
    
    // Nét vẽ gradient (dày ở giữa, mỏng ở đầu)
    if useSmoothBrush {
      context?.setShadow(offset: CGSize(width: 0.5, height: 0.5), blur: 1, color: strokeColor.withAlphaComponent(0.3).cgColor)
    }
    
    // Vẽ các đường đã hoàn thành trong lớp hiện tại
    for i in 0..<finishedLines.count {
      drawSmoothLine(finishedLines[i], color: finishedLinesColors[i], in: context)
    }
    
    // Vẽ đường hiện tại
    drawSmoothLine(currentLine, color: strokeColor, in: context)
    
    // Vẽ viền cho hình ảnh (chỉ để debug)
#if DEBUG
    let borderPath = UIBezierPath(rect: imageRect)
    UIColor.green.setStroke()
    borderPath.lineWidth = 2.0
    borderPath.stroke()
#endif
  }
  
  // Phương thức mới: vẽ đường mượt mà với đường cong Bézier
  private func drawSmoothLine(_ points: [CGPoint], color: UIColor, in context: CGContext?) {
    guard points.count > 0 else { return }
    
    if points.count == 1 {
      // Nếu chỉ có một điểm, vẽ một điểm tròn
      let point = points[0]
      let dotPath = UIBezierPath(arcCenter: point, radius: strokeWidth/2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
      color.setFill()
      dotPath.fill()
      return
    }
    
    // Tạo đường dẫn Bézier mượt mà
    let path = UIBezierPath()
    path.lineWidth = strokeWidth
    path.lineCapStyle = strokeCapStyle
    path.lineJoinStyle = strokeJoinStyle
    color.setStroke()
    
    // Đường với tối thiểu 2 điểm
    path.move(to: points[0])
    
    if points.count == 2 {
      // Nếu chỉ có 2 điểm, vẽ đường thẳng
      path.addLine(to: points[1])
    } else if points.count == 3 {
      // Với 3 điểm, sử dụng đường cong quadratic
      let midPoint = CGPoint(
        x: (points[1].x + points[2].x) / 2,
        y: (points[1].y + points[2].y) / 2)
      path.addQuadCurve(to: midPoint, controlPoint: points[1])
      path.addLine(to: points[2])
    } else {
      // Catmull-Rom spline cho đường rất mượt với nhiều điểm
      var i = 0
      while i < points.count - 1 {
        let currentPoint = points[i]
        let nextPoint = points[i+1]
        
        if i == 0 {
          // Điểm đầu tiên
          path.move(to: currentPoint)
          path.addLine(to: nextPoint)
        } else if i == points.count - 2 {
          // Điểm gần cuối
          path.addLine(to: nextPoint)
        } else if i < points.count - 2 {
          // Điểm ở giữa - sử dụng đường cong Bézier bậc 3
          let nextNextPoint = points[i+2]
          
          // Các điểm điều khiển cho đường cong Bézier bậc 3
          let controlPoint1 = CGPoint(
            x: currentPoint.x + (nextPoint.x - currentPoint.x) / 2,
            y: currentPoint.y + (nextPoint.y - currentPoint.y) / 2
          )
          
          let controlPoint2 = CGPoint(
            x: nextPoint.x - (nextNextPoint.x - currentPoint.x) / 2,
            y: nextPoint.y - (nextNextPoint.y - currentPoint.y) / 2
          )
          
          path.addCurve(to: nextPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        }
        
        i += 1
      }
    }
    
    // Vẽ đường
    path.stroke()
  }
  
  // MARK: - Public Methods
  
  // Đặt lại màu cần kiểm tra và phân tích lại hình ảnh
  func setTargetColor(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    targetColor = (r, g, b, a)
    
    if let templateImage = templateImage {
      analyzeImage(templateImage)
    }
  }
  
  // Phương thức mới: cho phép người dùng chọn màu từ một điểm trong hình ảnh
  func setTargetColorFromPoint(point: CGPoint) {
    guard let pixel = getPixelCoordinates(from: point),
          let cgImage = templateImage?.cgImage else {
      print("Không thể chọn màu từ điểm này")
      return
    }
    
    // Tạo context để đọc dữ liệu pixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * imageWidth
    let bitsPerComponent = 8
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    
    guard let context = CGContext(data: nil,
                                  width: imageWidth,
                                  height: imageHeight,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo) else { return }
    
    // Vẽ hình ảnh vào context
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
    
    guard let pixelData = context.data else { return }
    
    // Đọc màu từ tọa độ đã chọn
    let pixelInfo = Int(bytesPerRow * pixel.y + bytesPerPixel * pixel.x)
    let r = pixelData.load(fromByteOffset: pixelInfo, as: UInt8.self)
    let g = pixelData.load(fromByteOffset: pixelInfo + 1, as: UInt8.self)
    let b = pixelData.load(fromByteOffset: pixelInfo + 2, as: UInt8.self)
    let a = pixelData.load(fromByteOffset: pixelInfo + 3, as: UInt8.self)
    
    print("Đã chọn màu từ điểm (\(pixel.x), \(pixel.y)): R:\(r), G:\(g), B:\(b), A:\(a)")
    
    // Thiết lập màu mục tiêu với dung sai
    // Tăng/giảm giá trị để bắt được phạm vi màu rộng hơn
    targetColor = (
      r: r < 30 ? 0 : r - 30,  // Giảm ngưỡng đỏ
      g: g < 30 ? 0 : g - 30,  // Giảm ngưỡng xanh lục
      b: b > 225 ? 255 : b + 30, // Tăng ngưỡng xanh lam
      a: 100 // Ngưỡng alpha thấp hơn để bắt được nhiều pixel hơn
    )
    
    // Phân tích lại hình ảnh với màu mới
    if let templateImage = templateImage {
      analyzeImage(templateImage)
    }
  }
  
  // Phương thức mới: bắt toàn bộ vùng màu xanh trong ảnh, không cần ngưỡng cụ thể
  func detectBlueAreas() {
    guard let templateImage = templateImage else { return }
    
    // Reset targetColor về giá trị linh hoạt hơn
    targetColor = (r: 255, g: 255, b: 0, a: 100) // Chỉ cần blue > 0
    
    // Phân tích ảnh với logic đặc biệt
    let originalImage = templateImage
    analyzeImage(originalImage)
    
    // Sử dụng kỹ thuật khác nếu vẫn không tìm thấy điểm
    if coloredPoints.isEmpty {
      print("Thử phương pháp phân tích màu nâng cao...")
      
      if let cgImage = templateImage.cgImage {
        let width = Int(templateImage.size.width)
        let height = Int(templateImage.size.height)
        
        // Tạo context để đọc dữ liệu pixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else { return }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return }
        
        // Tìm tất cả các pixel không phải màu trắng (giả định nền trắng)
        for y in 0..<height {
          for x in 0..<width {
            let pixelInfo = Int(bytesPerRow * y + bytesPerPixel * x)
            let r = pixelData.load(fromByteOffset: pixelInfo, as: UInt8.self)
            let g = pixelData.load(fromByteOffset: pixelInfo + 1, as: UInt8.self)
            let b = pixelData.load(fromByteOffset: pixelInfo + 2, as: UInt8.self)
            let a = pixelData.load(fromByteOffset: pixelInfo + 3, as: UInt8.self)
            
            // Nếu pixel không phải màu trắng và có độ trong suốt cao
            if (r < 245 || g < 245 || b < 245) && a > 100 {
              let key = "\(x),\(y)"
              coloredPoints.insert(key)
            }
          }
        }
      }
    }
  }
  
  // Lấy thống kê về các điểm đã vẽ
  func getStatistics() -> (inside: Int, outside: Int, coloredTotal: Int, userTotal: Int) {
    return (insidePointsCount, outsidePointsCount, coloredPoints.count, userDrawnPoints.count)
  }
  
  // Reset chỉ các biến thống kê, giữ nguyên các đường vẽ
  func resetStatistics() {
    // Reset biến đếm điểm trong và ngoài
    insidePointsCount = 0
    outsidePointsCount = 0
    
    // Xóa các điểm user đã vẽ (trong bộ nhớ) nhưng giữ nguyên hiển thị
    userDrawnPoints.removeAll()
    
    // Reset thanh progress
    onProgressUpdate?(0, true)
    
    // Báo cập nhật phần trăm
    onColorPercentageUpdated?(0)
  }
  
  // Reset trạng thái vẽ nhưng giữ nguyên phân tích màu
  func resetDrawing() {
    currentLine = []
    finishedLines = []
    finishedLinesColors = []
    drawingLayers = [DrawingLayer(imageName: "rabit1")]
    currentLayerIndex = 0
    userDrawnPoints.removeAll()
    insidePointsCount = 0
    outsidePointsCount = 0
    
    // Reset thanh progress
    onProgressUpdate?(0, true)
    
    setNeedsDisplay()
  }
  
  // Hàm khởi tạo lớp vẽ mới khi chuyển ảnh mẫu
  func createNewLayer(forImageNamed imageName: String) {
    // Lưu lại các đường vẽ hiện tại vào lớp hiện tại
    if currentLayerIndex < drawingLayers.count {
      drawingLayers[currentLayerIndex].lines = finishedLines
      drawingLayers[currentLayerIndex].colors = finishedLinesColors
    }
    
    // Tạo lớp mới
    drawingLayers.append(DrawingLayer(imageName: imageName))
    currentLayerIndex = drawingLayers.count - 1
    
    // Xóa các đường vẽ hiện tại (nhưng không xóa bộ nhớ, vì đã được lưu trong lớp cũ)
    finishedLines = []
    finishedLinesColors = []
    
    // Vẽ lại view
    setNeedsDisplay()
  }
  
  // Phương thức mới để thiết lập độ chặt chẽ của việc chống vẽ đè
  func setOverlapProtection(level: Int) {
    minDistanceBetweenDrawnPoints = level
    
    // Nếu mức độ bảo vệ cao, tăng khoảng cách tối thiểu giữa các điểm
    if level > 3 {
      minDistance = 2.0 // Tăng khoảng cách tối thiểu giữa các điểm để ngăn họ quá gần nhau
    } else {
      minDistance = 1.0 // Giữ nguyên khoảng cách mặc định
    }
  }
}
