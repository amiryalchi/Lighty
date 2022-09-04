//
//  ViewController.swift
//  lighty
//
//  Created by Amir Yalchi on 2022-08-11.
//

import UIKit
import Photos
import PhotosUI
import AVFoundation

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let apertures: [Double] = [1.0, 1.2, 1.4, 2.0, 2.8, 4.0,5.6, 8.0, 11.0, 16.0, 22.0, 32.0]
    let isos: [Double] = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400]
    let shutters: [Double] = [1, 2, 4, 8, 15, 30, 60, 125, 250, 500, 1000, 2000, 4000]
    
    private var aperture: Double?
    private var iso: Double?
    private var shutter: Double?
    private var EV: Double?
    
    var binarySw: Bool = true
    var session: AVCaptureSession?
    let output = AVCapturePhotoOutput()
    let previewLayer = AVCaptureVideoPreviewLayer()

    var pickedImage = false
    var image: UIImage?
    var pickerView = UIPickerView()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        pickerView.delegate = self
        pickerView.dataSource = self

        previewLayer.backgroundColor = UIColor.systemRed.cgColor
        imageView.layer.addSublayer(previewLayer)
        
        checkCameraPermission()
        setupStackConstraints()
        
        apertureTextField.inputView = pickerView
        isoTextField.inputView = pickerView
        shutterTextField.inputView = pickerView
        
    }
    override func viewWillAppear(_ animated: Bool) {
       super.viewWillAppear(animated)
       
       AppUtility.lockOrientation(.portrait)
       // Or to rotate and lock
       // AppUtility.lockOrientation(.portrait, andRotateTo: .portrait)
       
   }

   override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       
       // Don't forget to reset when view is being removed
       AppUtility.lockOrientation(.all)
   }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = imageView.bounds
    }
    
    // MARK: UI ELEMENTS
    
    let imageView: UIImageView = {
        let iVieiw = UIImageView()
        iVieiw.layer.borderWidth = 5
        iVieiw.layer.cornerRadius = 10
        iVieiw.layer.borderColor = UIColor(red: 50/255, green: 151/255, blue: 163/255, alpha: 1).cgColor
        iVieiw.layer.masksToBounds = true
        return iVieiw
    }()
    
    let segmentedSwitch: UISegmentedControl = {
        let swt = UISegmentedControl(items: ["Aperture", "Shutter"])
        swt.backgroundColor = UIColor(red: 150/255, green: 51/255, blue: 163/255, alpha: 1)
        swt.selectedSegmentIndex = 0
        swt.addTarget(self, action: #selector(handleSegmentChange), for: .valueChanged)
        return swt
    }()
    
    
    let CButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(red: 150/255, green: 51/255, blue: 163/255, alpha: 1)
        button.setTitle("Calculate Exposure Value", for: .normal)
        button.setTitleColor(UIColor.white, for: .normal)
        button.layer.cornerRadius = 5
        button.titleLabel?.font = UIFont(name: "Roboto-Bold", size: 16)
        button.addTarget(self, action: #selector(ReTakePhoto), for: .touchUpInside)
        return button
    }()
    
    let EvTextField: UITextField = {
        let aTextField = UITextField()
        aTextField.placeholder = "Exposure Value"
        aTextField.textAlignment = .center
        aTextField.textColor = .white
        aTextField.tintColor = .black
        aTextField.isUserInteractionEnabled = false
        return aTextField
    }()
    let apertureTextField: UITextField = {
        let aTextField = UITextField()
        aTextField.placeholder = "F Stop"
        aTextField.textAlignment = .center
        aTextField.textColor = .white
        return aTextField
    }()
    let isoTextField: UITextField = {
        let aTextField = UITextField()
        aTextField.placeholder = "ISO"
        aTextField.textAlignment = .center
        aTextField.textColor = .white
        return aTextField
    }()
    let shutterTextField: UITextField = {
        let aTextField = UITextField()
        aTextField.placeholder = "Shutter Speed"
        aTextField.textAlignment = .center
        aTextField.textColor = .white
        return aTextField
    }()
    lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [isoTextField,apertureTextField,shutterTextField, EvTextField])
        stack.axis = .vertical
        stack.distribution = .fill
        stack.spacing = 10
        return stack
    }()
    
    
    // MARK: FUNCTIONS AND METHODS
    
    private func roundingByDecimal(inp: Double, dec: Double) -> Double {
        let fac = pow(10.0, dec)
        return Double(round(fac * inp) / fac )
    }
    
    @objc private func handleSegmentChange() {
        print(segmentedSwitch.selectedSegmentIndex)
        clearFields()
        self.view.endEditing(true)


        switch segmentedSwitch.selectedSegmentIndex {
        case 0: do {
            self.binarySw = true
//            calculateShutterSpeed(fNumber: aperture ?? 4.0, ev: EV ?? 0.0, iso: iso ?? 100)
        }
        case 1: do {
            self.binarySw = false
//            calculateFNumber(aprSpeed: shutter ?? 125.0, ev: EV ?? 0.0, iso: iso ?? 100)
        }
        default: do {
            self.binarySw = true
//            calculateShutterSpeed(fNumber: aperture ?? 4.0, ev: EV ?? 0.0, iso: iso ?? 100)
        }
        }
    }
    
    @objc func ReTakePhoto(){
        pickedImage = false
        if UIImagePickerController.isSourceTypeAvailable(.camera) && !pickedImage {
            let ImagePickerController = UIImagePickerController()
            ImagePickerController.delegate = self
            ImagePickerController.sourceType = .camera
            ImagePickerController.cameraFlashMode = .off
            self.present(ImagePickerController, animated: true, completion: nil)
            pickedImage = true
            clearFields()
        }
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage

        let dictionary = info[.mediaMetadata] as! NSDictionary
        guard let exif = dictionary["{Exif}"] as? NSDictionary else {return}
        guard let brg = exif["BrightnessValue"] as? Double? else {return}
        
        imageView.image = image
        print("BRIGHTNESS: ", dictionary)
        print("BRIGHTNESS EV: ", brg!)
        EV = brg
        EvTextField.text = "\(brg!)"
        
        self.dismiss(animated: true, completion: nil)
    }
    
    override func touchesBegan(_: Set<UITouch>, with: UIEvent?){
        self.view.endEditing(true)

    }
    
    // new camera method
    
    @objc private func didTapTakePhoto(){
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    private func checkCameraPermission(){
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self?.setUpCamera()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setUpCamera()
        @unknown default:
            break
        }
    }

    private func clearFields()
    {
        isoTextField.text = nil
        apertureTextField.text = nil
        shutterTextField.text = nil
    }
    
    private func setUpCamera() {
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                session.startRunning()
                self.session = session
            }
            catch {
                print(error)
            }
        }
    }
    
    
    // MARK: SHUTTER CALCULATOR
    
    func calculateShutterSpeed(fNumber: Double, ev: Double, isoe: Double) -> Double {
        
        var ss = exp(2 * log2(fNumber) - ev - log2(isoe / 3.125))

        self.aperture = fNumber
        self.EV = ev
        self.iso = isoe
        
        print("Calculated Sutter Speed: ", ss)
        
//        ss = calculateShutterByNewIso(iso: iso, shutterS: ss)
//        print ("Final Shutter Speed: ", ss)
        print("ISO IS: ", iso)
        print("F NUMBER: ", self.aperture)
        shutterTextField.text = "\(ss)"
        
        isoTextField.text = "\(iso)"
        apertureTextField.text = "\(self.aperture)"
        
        ss = shutterSpeedCategorizer(ss: ss)
        
        return ss
    }
    
    func calculateShutterByNewIso(iso: Double, shutterS: Double) -> Double {
        let newShutter: Double
        let factor = sqrt(iso / 100)
        newShutter = shutterS / (pow(2, factor))
        return newShutter
    }
    
    private func shutterSpeedCategorizer(ss: Double) -> Double {
        var sss: Double = 0.0
        
        if ss >= (1/4000) && ss < (1/2000) {
            sss = (1/2000)
        }
        else if ss >= (1/2000) && ss < (1/1000) {
            sss = (1/1000)
        }
        else if ss >= (1/1000) && ss < (1/500) {
            sss = (1/500)
        }
        else if ss >= (1/500) && ss < (1/250) {
            sss = (1/250)
        }
         else if ss >= (1/250) && ss < (1/125) {
            sss = 1/125
        }
         else if ss >= (1/125) && ss < (1/60) {
            sss = (1/60)
        }
        else if ss >= (1/60) && ss < (1/30) {
            sss = (1/30)
        }
        else if ss >= (1/30) && ss < (1/15) {
            sss = (1/15)
        }
        else if ss >= (1/15) && ss < (1/8) {
            sss = (1/8)
        }
        else if ss >= (1/8) && ss < (1/4) {
            sss = (1/4)
        }
        else if ss >= (1/4) && ss < (1/2) {
            sss = (1/2)
        }
        else if ss >= (1/2) && ss < 1 {
            sss = 1
        }
        else if ss >= 1 && ss < 2 {
            sss = 2
        }
        else if ss >= 2 && ss < 4 {
            sss = 4
        }
        else if ss >= 4 && ss < 8 {
            sss = 8
        }
        else if ss >= 8 && ss < 15{
            sss = 15
        }
        else if ss >= 15 && ss < 30 {
            sss = 30
        }
        else if ss >= 30 && ss < 60 {
            sss = 60
        }
        else if ss >= 60 {
            sss = floor(ss)
        }
        
        sss = roundingByDecimal(inp: sss, dec: 4.0)
        
        print("sgutter speed AFTER CATEGORIZING: ", sss)
        shutterTextField.text = "\(sss)"
        return sss
    }
    
    // MARK: F NUMBER CALCULATOR
    
    func calculateFNumber(aprSpeed: Double, ev: Double, iso: Double) -> Double {
            
//        var fn = exp(ev + log2(1 / aprSpeed)) / 2
        var FN = exp((ev + log2(1 / aprSpeed) + log2(iso / 3.125)) / 2 )
        
        print ("Calculated F Number: ", FN)
        
//        FN = calculateFNumberByNewIso(iso: iso, fnumber: FN)
        print ("Final F Number: ", FN)
        print("ISO IS : ", iso)
        print("SHUTTER SPEED : ", shutter)
        
        isoTextField.text = "\(iso)"
//        shutterTextField.text = "\(shutter)"
        
        FN = fNumberCategorizer(fn: FN)
        
        return FN
    }
    
    func calculateFNumberByNewIso(iso: Double, fnumber: Double) -> Double {
        
        let factor = sqrt(iso / 100)
        let newFNumber: Double
        
        if factor == 1 {
            newFNumber = fnumber
            
        } else if factor > 1 {
            
            newFNumber = fnumber + factor
            
        }else {
            
            newFNumber = fnumber - factor
        }
        print("*** newFNumber: ", newFNumber)
        return newFNumber
        
    }
    
    private func fNumberCategorizer(fn: Double) -> Double {
        var ffn: Double = 0.0
        
        if fn < 1 {
            ffn = 0.95
            apertureTextField.text = "Too Dark!"
            return ffn
        }
        else if fn >= 1 && fn < 1.2 {
            ffn = 1.0
        }
        else if fn >= 1.2 && fn < 1.4 {
            ffn = 1.2
        }
        else if fn >= 1.4 && fn < 1.8 {
            ffn = 1.4
        }
        else if fn >= 1.8 && fn < 2 {
            ffn = 1.8
        }
        else if fn >= 2 && fn < 2.4 {
            ffn = 2
        }
        else if fn >= 2.4 && fn < 2.8 {
            ffn = 2.4
        }
        else if fn >= 2.8 && fn < 3.5 {
            ffn = 2.8
        }
        else if fn >= 3.5 && fn < 4.0 {
            ffn = 3.5
        }
        else if fn >= 4.0 && fn < 5.6 {
            ffn = 4.0
        }
        else if fn >= 5.6 && fn < 8.0 {
            ffn = 5.6
        }
        else if fn >= 8.0 && fn < 11.0 {
            ffn = 8.0
        }
        else if fn >= 11.0 && fn < 16.0 {
            ffn = 11.0
        }
        else if fn >= 16.0 && fn < 22.0 {
            ffn = 16.0
        }
        else if fn >= 22.0 && fn < 32.0 {
            ffn = 22.0
        }
        else if fn >= 32.0 {
            ffn = 32
        }
        apertureTextField.text = "\(ffn)"
        print("F NUMBER AFTER CATEGORIZING: ", ffn)
        return ffn
    }
    
    // MARK: EV CALCULATOR
    
    func calculateEV(isoP: Double, aperture: Double, shutter: Double) -> Double {
        return (2 * log2(aperture)) - log2(shutter) - log2(isoP / 3.125)
        
    }
    
    func logC(value: Double, base: Double) -> Double {
        return log(value)/log(base)
    }
    
    func getExif(image: NSData) -> NSDictionary {
        let imageSourceRef = CGImageSourceCreateWithData(image, nil)
        let currentProperties = CGImageSourceCopyPropertiesAtIndex(imageSourceRef!, 0, nil)
        let mutableDic = NSMutableDictionary(dictionary: currentProperties!)
        return mutableDic
    }
    
    // MARK: UI AUTO LAYOUT
    
    func setupStackConstraints(){
        
        view.addSubview(stackView)
        view.addSubview(CButton)
        view.addSubview(imageView)
        view.addSubview(segmentedSwitch)
        
        
        // constraints x, y, h, w for inputContainerView
        stackView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        CButton.translatesAutoresizingMaskIntoConstraints = false
        segmentedSwitch.translatesAutoresizingMaskIntoConstraints = false

        segmentedSwitch.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        segmentedSwitch.bottomAnchor.constraint(equalTo: imageView.topAnchor, constant: -10).isActive = true
        segmentedSwitch.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -24).isActive = true
        segmentedSwitch.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        CButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        CButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60).isActive = true
        CButton.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -24).isActive = true
        CButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -24).isActive = true
        stackView.bottomAnchor.constraint(equalTo: CButton.topAnchor, constant: -50).isActive = true
        stackView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        imageView.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -30).isActive = true
        imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: +100).isActive = true
        imageView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: +30).isActive = true
        imageView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30).isActive = true
        
    }

}

    // MARK: EXTENSIONS

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {

        switch component {
        case 0: return "\(isos[row])"
        case 1: do {
            if binarySw {
            
                return "\(apertures[row])"
            } else {
                return "\(shutters[row])"
            }
        }
        default: return "\(shutters[row])"
        }

    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0: return isos.count
        case 1: do {
            if binarySw {
                return apertures.count
            } else {
                return shutters.count
            }
        }
        default:
            return shutters.count
        }
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {

        switch component {
        case 0: do {
            self.iso = isos[row]
            if self.binarySw && self.shutter != nil {
                aperture = calculateFNumber(aprSpeed: self.shutter!, ev: EV ?? 0.0, iso: self.iso!)
            } else if self.binarySw == false && self.aperture != nil {
                shutter = calculateShutterSpeed(fNumber: self.aperture!, ev: EV ?? 0.0, isoe: self.iso!)
            }
            return isoTextField.text = "\(self.iso!)"
        }
        case 1: do {
            if binarySw {
                aperture = apertures[row]
                calculateShutterSpeed(fNumber: aperture ?? 4, ev: EV ?? 0.0, isoe: iso ?? 100.0)
                return apertureTextField.text = "\(self.aperture!)"
            } else {
                shutter = shutters[row]
                calculateFNumber(aprSpeed: shutter ?? 125, ev: EV ?? 0.0, iso: iso ?? 100.0)
                return shutterTextField.text = "\(shutter!)"
            }
            
        }
        default: do {

            return
        }
        }
    }
    
    
    
}

extension UIImage {
    
    func scaleSpectRatio(targetSize: CGSize) -> UIImage {
        let wRatio = targetSize.width / size.width
        let hRatio = targetSize.height / size.height
        let scaleFactor = min(wRatio, hRatio)
        
        let scaledImageSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let renderer = UIGraphicsImageRenderer(size: scaledImageSize)
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero, size: scaledImageSize
            ))
        }
        return scaledImage
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        let image = UIImage(data: data)
        session?.stopRunning()
        imageView.image = image
    
        print("DATA : ", image?.imageAsset)
    
    }
}
struct AppUtility {

    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
    
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }

    /// OPTIONAL Added method to adjust lock and rotate to the desired orientation
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
   
        self.lockOrientation(orientation)
    
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }

}
extension UIColor {
    
}
