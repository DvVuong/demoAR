//
//  ViewController.swift
//  DemoDraw
//
//  Created by VuongDv on 18/03/2025.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
  
  private var drawingView: DrawingView!
  private var percentageLabel: UILabel!
  private var statisticsLabel: UILabel!
  private var resetButton: UIButton!
  private var statsButton: UIButton!
  private var detectButton: UIButton!
  
  // Thay đổi quản lý ảnh để hỗ trợ nhiều ảnh
  private var currentImageIndex: Int = 1 // Ảnh hiện tại đang hiển thị
  private var maxImages: Int = 5 // Số ảnh tối đa (giả sử bạn có 5 ảnh rabit1, rabit2, ..., rabit5)
  private var nextTemplateImage: UIImage? // Ảnh tiếp theo sẽ chuyển sang
  // Biến kiểm tra xem đã thay đổi ảnh chưa
  private var hasChangedImage: Bool = false
  // Thêm button để đổi ảnh
  private var changeImageButton: UIButton!
  // Thêm button để chọn màu vẽ
  private var colorPickerButton: UIButton!
  // Thêm nhãn hiển thị màu vẽ hiện tại
  private var currentColorLabel: UILabel!
  
  // Loại bỏ progress bar cũ và thêm các thành phần mới
  private var progressContainerView: UIView! // View chứa tiến trình
  private var greenProgressView: UIView! // Thanh màu xanh (vẽ trong vùng)
  private var redProgressView: UIView! // Thanh màu đỏ (vẽ ngoài vùng)
  private var progressPercentLabel: UILabel! // Nhãn phần trăm
  // Thêm slider mới
  private var noOverlapSlider: UISlider! // Slider để điều chỉnh khoảng cách tối thiểu giữa các điểm vẽ
  
  // Biến lưu tên ảnh hiện tại để hiển thị
  private var currentImageName: String = ""
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupUI()
  }
  
  private func setupUI() {
    // Tạo template image (ảnh đầu tiên)
    currentImageIndex = 1
    currentImageName = "rabit\(currentImageIndex)"
    let templateImage = UIImage(named: currentImageName)
    
    // Tải ảnh tiếp theo (ảnh thứ 2)
    loadNextTemplateImage()
    
    // Tạo nhãn tiêu đề cho thanh progress
    let progressTitleLabel = UILabel(frame: CGRect(x: 20, y: 10, width: view.bounds.width - 40, height: 20))
    progressTitleLabel.text = "Tiến độ tô màu:"
    progressTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    progressTitleLabel.textAlignment = .left
    view.addSubview(progressTitleLabel)
    
    // Tạo container cho thanh progress
    progressContainerView = UIView(frame: CGRect(x: 20, y: 35, width: view.bounds.width - 100, height: 20))
    progressContainerView.backgroundColor = .lightGray
    progressContainerView.layer.cornerRadius = 5
    progressContainerView.layer.borderWidth = 1
    progressContainerView.layer.borderColor = UIColor.gray.cgColor
    progressContainerView.clipsToBounds = true
    view.addSubview(progressContainerView)
    
    // Tạo thanh progress màu xanh (hiển thị điểm vẽ trong vùng màu)
    greenProgressView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: progressContainerView.bounds.height))
    greenProgressView.backgroundColor = .systemGreen
    progressContainerView.addSubview(greenProgressView)
    
    // Tạo thanh progress màu đỏ (hiển thị điểm vẽ ngoài vùng màu)
    redProgressView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: progressContainerView.bounds.height))
    redProgressView.backgroundColor = .systemRed
    progressContainerView.addSubview(redProgressView)
    
    // Thêm nhãn hiển thị phần trăm bên cạnh thanh progress
    progressPercentLabel = UILabel(frame: CGRect(x: view.bounds.width - 70, y: 35, width: 50, height: 20))
    progressPercentLabel.textAlignment = .left
    progressPercentLabel.text = "0%"
    progressPercentLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
    view.addSubview(progressPercentLabel)
    
    // Thêm một nhãn để hiển thị ý nghĩa của màu sắc
    let colorLegendLabel = UILabel(frame: CGRect(x: 20, y: 60, width: view.bounds.width - 40, height: 20))
    colorLegendLabel.text = "🟢 Trong vùng màu | 🔴 Ngoài vùng màu"
    colorLegendLabel.font = UIFont.systemFont(ofSize: 12)
    colorLegendLabel.textAlignment = .center
    view.addSubview(colorLegendLabel)
    
    // Tạo drawing view (điều chỉnh vị trí xuống thấp hơn để tạo chỗ cho các phần tử mới)
    drawingView = DrawingView(frame: CGRect(x: 0, y: 120, width: view.bounds.width, height: view.bounds.height - 220), templateImage: templateImage, imageName: currentImageName)
    drawingView.strokeColor = .red
    
    // Cấu hình nét vẽ mượt mà
    drawingView.strokeWidth = 8.0 // Nét vẽ dày hơn để nhìn mượt hơn
    drawingView.strokeCapStyle = .round
    drawingView.strokeJoinStyle = .round
    drawingView.brushOpacity = 0.8 // Độ mờ nhẹ để có cảm giác mượt mà
    drawingView.useSmoothBrush = true
    
    view.addSubview(drawingView)
    
    // Thêm slider để điều chỉnh kích thước nét vẽ
    let brushSizeLabel = UILabel(frame: CGRect(x: view.bounds.width - 200, y: 85, width: 100, height: 20))
    brushSizeLabel.text = "Nét vẽ:"
    brushSizeLabel.font = UIFont.systemFont(ofSize: 14)
    view.addSubview(brushSizeLabel)
    
    let brushSizeSlider = UISlider(frame: CGRect(x: view.bounds.width - 150, y: 85, width: 130, height: 20))
    brushSizeSlider.minimumValue = 2.0
    brushSizeSlider.maximumValue = 20.0
    brushSizeSlider.value = 8.0
    brushSizeSlider.addTarget(self, action: #selector(brushSizeChanged(_:)), for: .valueChanged)
    view.addSubview(brushSizeSlider)
    
    // Thêm slider để điều chỉnh khoảng cách tối thiểu giữa các điểm vẽ
    let noOverlapLabel = UILabel(frame: CGRect(x: 20, y: view.bounds.height - 160, width: 200, height: 20))
    noOverlapLabel.text = "Chống vẽ đè:"
    noOverlapLabel.font = UIFont.systemFont(ofSize: 14)
    view.addSubview(noOverlapLabel)
    
    noOverlapSlider = UISlider(frame: CGRect(x: 130, y: view.bounds.height - 160, width: 150, height: 20))
    noOverlapSlider.minimumValue = 0
    noOverlapSlider.maximumValue = 5
    noOverlapSlider.value = Float(drawingView.minDistanceBetweenDrawnPoints)
    noOverlapSlider.addTarget(self, action: #selector(noOverlapChanged(_:)), for: .valueChanged)
    view.addSubview(noOverlapSlider)
    
    // Thiết lập callback khi người dùng vẽ ra ngoài vùng màu
    drawingView.onDrawOutsideColoredArea = { [weak self] point in
      // Hiển thị điểm trong debug log
      print("User vẽ ra ngoài vùng màu tại điểm: \(point)")
    }
    
    // Thiết lập callback khi người dùng vẽ vào trong vùng màu
    drawingView.onDrawInsideColoredArea = { [weak self] point in
      // Hiển thị điểm trong debug log
      print("User vẽ vào trong vùng màu tại điểm: \(point)")
    }
    
    // Tạo button chuyển ảnh (ban đầu ẩn)
    changeImageButton = UIButton(frame: CGRect(x: (view.bounds.width - 150) / 2, y: view.bounds.height - 130, width: 150, height: 40))
    changeImageButton.setTitle("Chuyển hình", for: .normal)
    changeImageButton.backgroundColor = .systemOrange
    changeImageButton.layer.cornerRadius = 8
    changeImageButton.addTarget(self, action: #selector(changeImageButtonTapped), for: .touchUpInside)
    changeImageButton.isHidden = true // Ban đầu ẩn button
    view.addSubview(changeImageButton)
    
    // Thêm nhãn hiển thị màu vẽ hiện tại
    currentColorLabel = UILabel(frame: CGRect(x: 20, y: view.bounds.height - 120, width: view.bounds.width - 40, height: 30))
    currentColorLabel.textAlignment = .center
    currentColorLabel.text = "Màu vẽ hiện tại: Đỏ"
    currentColorLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    currentColorLabel.textColor = .red
    view.addSubview(currentColorLabel)
    
    // Thiết lập callback khi tỷ lệ phần trăm vẽ được cập nhật
    drawingView.onColorPercentageUpdated = { [weak self] percentage in
      guard let self = self else { return }
      
      self.percentageLabel.text = "Đã tô: \(Int(percentage))%"
      
      // Lấy thống kê hiện tại
      let stats = self.drawingView.getStatistics()
      
      // Khi số điểm tô bên trong đạt 500 và chưa thay đổi ảnh
      if stats.inside >= 500 && !self.hasChangedImage {
        // Hiển thị button chuyển ảnh
        self.changeImageButton.isHidden = false
        
        // Cập nhật tiêu đề cho button chuyển ảnh (hiển thị tên ảnh tiếp theo)
        let nextIndex = (self.currentImageIndex % self.maxImages) + 1
        let nextImageName = "rabit\(nextIndex)"
        self.changeImageButton.setTitle("Chuyển sang \(nextImageName)", for: .normal)
        
        // Thông báo cho người dùng khi đạt đủ điểm
        // Bỏ comment dòng dưới nếu muốn hiển thị thông báo khi đạt đủ điểm
        // self.showAlert(message: "Chúc mừng! Bạn đã tô được 500 điểm!\nBấm nút để xem hình mới.")
      }
      
      // Cập nhật thống kê
      self.updateStatistics()
    }
    
    // Thiết lập callback khi cần cập nhật thanh progress
    drawingView.onProgressUpdate = { [weak self] progress, isInside in
      guard let self = self else { return }
      
      let stats = self.drawingView.getStatistics()
      let totalPoints = stats.inside + stats.outside
      
      if totalPoints == 0 {
        // Reset progress nếu không có điểm nào
        self.updateProgressBars(inside: 0, outside: 0)
        self.progressPercentLabel.text = "0%"
        self.progressPercentLabel.textColor = .black
        return
      }
      
      let insideRatio = CGFloat(stats.inside) / CGFloat(600)
      let outsideRatio = CGFloat(stats.outside) / CGFloat(600)
      
      // Tính tổng phần trăm
      let totalProgress = Int((insideRatio + outsideRatio) * 100)
      
      // Hiệu ứng chuyển động mượt mà cho thanh progress
      UIView.animate(withDuration: 0.2) {
        self.updateProgressBars(inside: insideRatio, outside: outsideRatio)
        // self.progressPercentLabel.text = "\(500)%"
        self.progressPercentLabel.isHidden = true
        // Đổi màu nhãn dựa vào số điểm
        if stats.inside > stats.outside {
          self.progressPercentLabel.textColor = .systemGreen
        } else if stats.outside > 0 {
          self.progressPercentLabel.textColor = .systemRed
        } else {
          self.progressPercentLabel.textColor = .black
        }
      }
    }
    
    // Tạo label hiển thị tỷ lệ phần trăm (điều chỉnh vị trí)
    percentageLabel = UILabel(frame: CGRect(x: 20, y: 80, width: view.bounds.width - 40, height: 30))
    percentageLabel.textAlignment = .center
    percentageLabel.text = "Đã tô: 0%"
    percentageLabel.font = UIFont.boldSystemFont(ofSize: 16)
    view.addSubview(percentageLabel)
    
    // Tạo label hiển thị thống kê (điều chỉnh vị trí)
    statisticsLabel = UILabel(frame: CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 20))
    statisticsLabel.textAlignment = .center
    statisticsLabel.text = "Trong/Ngoài: 0/0"
    statisticsLabel.font = UIFont.systemFont(ofSize: 14)
    view.addSubview(statisticsLabel)
    
    // Cấu hình các nút
    let buttonWidth: CGFloat = 80
    let buttonHeight: CGFloat = 40
    let buttonSpacing: CGFloat = 10
    let totalButtonsWidth = buttonWidth * 3 + buttonSpacing * 2
    let startX = (view.bounds.width - totalButtonsWidth) / 2
    
    // Tạo nút reset
    resetButton = UIButton(frame: CGRect(x: startX, y: view.bounds.height - 80, width: buttonWidth, height: buttonHeight))
    resetButton.setTitle("Làm lại", for: .normal)
    resetButton.backgroundColor = .systemBlue
    resetButton.layer.cornerRadius = 8
    resetButton.addTarget(self, action: #selector(resetDrawing), for: .touchUpInside)
    view.addSubview(resetButton)
    
    // Tạo nút thống kê
    statsButton = UIButton(frame: CGRect(x: startX + buttonWidth + buttonSpacing, y: view.bounds.height - 80, width: buttonWidth, height: buttonHeight))
    statsButton.setTitle("Thống kê", for: .normal)
    statsButton.backgroundColor = .systemGreen
    statsButton.layer.cornerRadius = 8
    statsButton.addTarget(self, action: #selector(showStatistics), for: .touchUpInside)
    view.addSubview(statsButton)
    
    // Tạo nút phát hiện màu
    detectButton = UIButton(frame: CGRect(x: startX + (buttonWidth + buttonSpacing) * 2, y: view.bounds.height - 80, width: buttonWidth, height: buttonHeight))
    detectButton.setTitle("Phát hiện", for: .normal)
    detectButton.backgroundColor = .systemPurple
    detectButton.layer.cornerRadius = 8
    detectButton.addTarget(self, action: #selector(detectColors), for: .touchUpInside)
    view.addSubview(detectButton)
    
    // Thêm button chọn màu vẽ
    colorPickerButton = UIButton(frame: CGRect(x: 20, y: view.bounds.height - 80, width: buttonWidth, height: buttonHeight))
    colorPickerButton.setTitle("Chọn màu", for: .normal)
    colorPickerButton.backgroundColor = .systemOrange
    colorPickerButton.layer.cornerRadius = 8
    colorPickerButton.addTarget(self, action: #selector(showColorPicker), for: .touchUpInside)
    view.addSubview(colorPickerButton)
  }
  
  // Hàm mới để cập nhật thanh progress
  private func updateProgressBars(inside: CGFloat, outside: CGFloat) {
    let containerWidth = progressContainerView.bounds.width
    
    // Tính toán chiều rộng của mỗi thanh progress
    let greenWidth = inside * containerWidth
    let redWidth = outside * containerWidth
    
    // Cập nhật chiều rộng của các thanh progress
    greenProgressView.frame = CGRect(x: 0, y: 0, width: greenWidth, height: progressContainerView.bounds.height)
    redProgressView.frame = CGRect(x: greenWidth, y: 0, width: redWidth, height: progressContainerView.bounds.height)
  }
  
  private func updateStatistics() {
    let stats = drawingView.getStatistics()
    statisticsLabel.text = "Trong/Ngoài: \(stats.inside)/\(stats.outside)"
  }
  
  @objc private func resetDrawing() {
    // Reset trạng thái vẽ nhưng giữ nguyên phân tích màu
    drawingView.resetDrawing()
    
    // Đặt lại ảnh ban đầu nếu đã thay đổi
    if hasChangedImage {
      hasChangedImage = false
      // Quay trở lại ảnh đầu tiên
      currentImageIndex = 1
      currentImageName = "rabit\(currentImageIndex)"
      let originalImage = UIImage(named: currentImageName)
      
      UIView.transition(with: self.drawingView, duration: 0.5, options: .transitionCrossDissolve, animations: {
        self.drawingView.templateImage = originalImage
        self.drawingView.setNeedsDisplay()
        // Đặt lại màu vẽ về màu mặc định (đỏ)
        self.drawingView.strokeColor = .red
      }, completion: nil)
      
      // Tải ảnh tiếp theo
      loadNextTemplateImage()
    } else {
      // Đặt lại màu vẽ về màu mặc định (đỏ) kể cả khi chưa thay đổi ảnh
      self.drawingView.strokeColor = .red
    }
    
    // Cập nhật nhãn màu hiện tại
    updateCurrentColorLabel()
    
    // Ẩn button chuyển ảnh
    changeImageButton.isHidden = true
    
    // Cập nhật UI
    percentageLabel.text = "Đã tô: 0%"
    statisticsLabel.text = "Trong/Ngoài: 0/0"
    
    // Reset thanh progress
    updateProgressBars(inside: 0, outside: 0)
    progressPercentLabel.text = "0%"
    progressPercentLabel.textColor = .black
  }
  
  @objc private func showStatistics() {
    let stats = drawingView.getStatistics()
    
    let message = """
        Thống kê chi tiết:
        
        Số điểm vẽ trong vùng màu: \(stats.inside)
        Số điểm vẽ ngoài vùng màu: \(stats.outside)
        Tổng số điểm trong vùng màu: \(stats.coloredTotal)
        Tổng số điểm đã vẽ: \(stats.userTotal)
        
        Tỷ lệ tô màu: \(Int((Double(stats.inside) / Double(stats.coloredTotal > 0 ? stats.coloredTotal : 1)) * 100))%
        """
    
    showAlert(message: message)
  }
  
  @objc private func detectColors() {
    // Thông báo để người dùng biết hệ thống đang xử lý
    let loadingAlert = UIAlertController(title: "Đang phân tích hình ảnh", message: "Vui lòng đợi...", preferredStyle: .alert)
    present(loadingAlert, animated: true)
    
    // Thực hiện phát hiện màu sau một khoảng thời gian ngắn
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      // Gọi phương thức phát hiện màu
      self.drawingView.detectBlueAreas()
      
      // Lấy thống kê mới
      let stats = self.drawingView.getStatistics()
      
      // Cập nhật UI
      self.statisticsLabel.text = "Trong/Ngoài: \(stats.inside)/\(stats.outside)"
      
      // Đóng thông báo đang xử lý
      loadingAlert.dismiss(animated: true) {
        // Hiển thị kết quả
        self.showAlert(message: "Đã phát hiện \(stats.coloredTotal) điểm có màu cần tô!")
      }
    }
  }
  
  @objc private func brushSizeChanged(_ sender: UISlider) {
    drawingView.strokeWidth = CGFloat(sender.value)
    // Cập nhật UI để phản ánh sự thay đổi
    drawingView.setNeedsDisplay()
  }
  
  @objc private func changeImageButtonTapped() {
    if !hasChangedImage {
      hasChangedImage = true
      
      // Thay đổi ảnh template
      if let newImage = self.nextTemplateImage {
        // Cập nhật chỉ số ảnh hiện tại
        currentImageIndex = (currentImageIndex % maxImages) + 1
        currentImageName = "rabit\(currentImageIndex)"
        
        // Tạo lớp vẽ mới trước khi thay đổi ảnh
        drawingView.createNewLayer(forImageNamed: currentImageName)
        
        // Đảm bảo chất lượng hình ảnh
        let highQualityImage = newImage.withRenderingMode(.alwaysOriginal)
        
        // Thay đổi ảnh và tạo hiệu ứng
        UIView.transition(with: self.drawingView, duration: 1.0, options: .transitionCrossDissolve, animations: {
          self.drawingView.templateImage = highQualityImage
          self.drawingView.setNeedsDisplay()
          
          // Thay đổi màu vẽ cho các nét vẽ mới
          // Sử dụng màu khác nhau cho mỗi ảnh
          switch self.currentImageIndex % 7 {
          case 0:
            self.drawingView.strokeColor = .red
          case 1:
            self.drawingView.strokeColor = .blue
          case 2:
            self.drawingView.strokeColor = .green
          case 3:
            self.drawingView.strokeColor = .orange
          case 4:
            self.drawingView.strokeColor = .purple
          case 5:
            self.drawingView.strokeColor = .brown
          case 6:
            self.drawingView.strokeColor = .magenta
          default:
            self.drawingView.strokeColor = .black
          }
          
          // Cập nhật nhãn màu hiện tại
          self.updateCurrentColorLabel()
        }, completion: { _ in
          // KHÔNG reset drawing, giữ lại các đường vẽ
          
          // Phân tích lại vùng màu với ảnh mới
          self.detectColorsForNewTemplate()
          
          // Đặt lại các biến đếm
          self.percentageLabel.text = "Đã tô: 0%"
          self.statisticsLabel.text = "Trong/Ngoài: 0/0"
          
          // Reset thanh progress
          self.updateProgressBars(inside: 0, outside: 0)
          self.progressPercentLabel.text = "0%"
          self.progressPercentLabel.textColor = .black
          
          // Thêm thông báo cho người dùng biết về sự thay đổi màu vẽ và ảnh
          self.showAlert(message: "Bạn đã chuyển sang hình mới '\(self.currentImageName)'! Màu vẽ đã thay đổi, các nét vẽ cũ vẫn giữ nguyên dưới lớp hình mới.")
          
          // Tải ảnh tiếp theo cho lần chuyển sau
          self.loadNextTemplateImage()
          
          // Đặt lại trạng thái đã thay đổi ảnh để có thể tiếp tục đếm cho lần sau
          self.hasChangedImage = false
        })
        
        // Ẩn button sau khi đã chuyển ảnh
        changeImageButton.isHidden = true
      }
    }
  }
  
  // Thêm phương thức mới để phân tích lại vùng màu khi thay đổi ảnh
  private func detectColorsForNewTemplate() {
    // Hiển thị thông báo đang phân tích
    let loadingAlert = UIAlertController(title: "Đang phân tích hình ảnh mới", message: "Vui lòng đợi...", preferredStyle: .alert)
    present(loadingAlert, animated: true)
    
    // Thực hiện phân tích sau một khoảng thời gian ngắn
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      // Reset hoàn toàn các biến đếm trong drawingView
      self.drawingView.resetStatistics()
      
      // Phát hiện lại các vùng màu với ảnh mới
      self.drawingView.detectBlueAreas()
      
      // Cập nhật UI
      self.updateStatistics()
      
      // Đóng thông báo
      loadingAlert.dismiss(animated: true) {
        // Thông báo hoàn tất
        self.showAlert(message: "Đã hoàn tất phân tích hình ảnh mới!")
      }
    }
  }
  
  @objc private func showColorPicker() {
    // Tạo alert controller với style actionSheet
    let alertController = UIAlertController(title: "Chọn màu vẽ", message: nil, preferredStyle: .actionSheet)
    
    // Thêm các lựa chọn màu
    alertController.addAction(UIAlertAction(title: "Đỏ", style: .default) { _ in
      self.drawingView.strokeColor = .red
      self.updateCurrentColorLabel()
    })
    
    alertController.addAction(UIAlertAction(title: "Xanh lam", style: .default) { _ in
      self.drawingView.strokeColor = .blue
      self.updateCurrentColorLabel()
    })
    
    alertController.addAction(UIAlertAction(title: "Xanh lá", style: .default) { _ in
      self.drawingView.strokeColor = .green
      self.updateCurrentColorLabel()
    })
    
    alertController.addAction(UIAlertAction(title: "Vàng", style: .default) { _ in
      self.drawingView.strokeColor = .yellow
      self.updateCurrentColorLabel()
    })
    
    alertController.addAction(UIAlertAction(title: "Cam", style: .default) { _ in
      self.drawingView.strokeColor = .orange
      self.updateCurrentColorLabel()
    })
    
    alertController.addAction(UIAlertAction(title: "Tím", style: .default) { _ in
      self.drawingView.strokeColor = .purple
      self.updateCurrentColorLabel()
    })
    
    alertController.addAction(UIAlertAction(title: "Đen", style: .default) { _ in
      self.drawingView.strokeColor = .black
      self.updateCurrentColorLabel()
    })
    
    alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
    
    // Hiển thị alert controller
    self.present(alertController, animated: true, completion: nil)
  }
  
  // Thêm phương thức để cập nhật nhãn màu hiện tại
  private func updateCurrentColorLabel() {
    let colorName: String
    let textColor: UIColor
    
    switch drawingView.strokeColor {
    case .red:
      colorName = "Đỏ"
      textColor = .red
    case .blue:
      colorName = "Xanh lam"
      textColor = .blue
    case .green:
      colorName = "Xanh lá"
      textColor = .green
    case .yellow:
      colorName = "Vàng"
      textColor = .yellow
    case .orange:
      colorName = "Cam"
      textColor = .orange
    case .purple:
      colorName = "Tím"
      textColor = .purple
    case .black:
      colorName = "Đen"
      textColor = .black
    default:
      colorName = "Tùy chỉnh"
      textColor = drawingView.strokeColor
    }
    
    currentColorLabel.text = "Màu vẽ hiện tại: \(colorName)"
    currentColorLabel.textColor = textColor
  }
  
  @objc private func noOverlapChanged(_ sender: UISlider) {
    // Cập nhật giá trị khoảng cách tối thiểu giữa các điểm vẽ
    let value = Int(sender.value)
    
    // Sử dụng phương thức mới để thiết lập bảo vệ chống vẽ đè
    drawingView.setOverlapProtection(level: value)
    
    // Hiển thị thông báo về cài đặt mới
    let message: String
    switch value {
    case 0:
      message = "Đã tắt tính năng chống vẽ đè (có thể vẽ đè và vẫn tính điểm)"
    case 1:
      message = "Mức 1: Điểm cũ sẽ không được tính lại"
    case 2:
      message = "Mức 2: Điểm cũ sẽ không được tính lại"
    case 3:
      message = "Mức 3: Điểm cũ sẽ không được tính lại"
    case 4:
      message = "Mức 4: Điểm cũ sẽ không được tính lại"
    default:
      message = "Mức 5: Điểm cũ sẽ không được tính lại"
    }
    
    // Cập nhật tiêu đề của slider
    let noOverlapStatusLabel = view.subviews.first { $0 is UILabel && ((($0 as! UILabel).text?.starts(with: "Chống vẽ đè:")) != nil) } as? UILabel
    if let label = noOverlapStatusLabel {
      label.text = "Chống vẽ đè: \(value > 0 ? "Bật" : "Tắt")"
    }
    
    // Hiển thị toast thông báo
    showToast(message: message)
  }
  
  // Hiển thị thông báo nhỏ tạm thời
  private func showToast(message: String) {
    let toastLabel = UILabel(frame: CGRect(x: view.frame.width/2 - 150, y: view.frame.height - 200, width: 300, height: 35))
    toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    toastLabel.textColor = .white
    toastLabel.textAlignment = .center
    toastLabel.text = message
    toastLabel.alpha = 1.0
    toastLabel.layer.cornerRadius = 10
    toastLabel.clipsToBounds = true
    view.addSubview(toastLabel)
    
    UIView.animate(withDuration: 2.0, delay: 0.5, options: .curveEaseOut, animations: {
      toastLabel.alpha = 0.0
    }, completion: { _ in
      toastLabel.removeFromSuperview()
    })
  }
  
  private func showAlert(message: String) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }
  
  private func loadNextTemplateImage() {
    // Tính toán chỉ số ảnh tiếp theo
    let nextIndex = (currentImageIndex % maxImages) + 1
    
    // Tải ảnh tiếp theo
    let nextImageName = "rabit\(nextIndex)"
    nextTemplateImage = UIImage(named: nextImageName)?.withRenderingMode(.alwaysOriginal)
    
    print("Đã tải ảnh tiếp theo: \(nextImageName)")
  }
}


