//
//  ViewController.swift
//  Object Detection Live Stream
//
//  Created by Alexey Korotkov on 6/25/19.
//  Copyright © 2019 Alexey Korotkov. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import VideoToolbox
import SwiftUI



//MARK: Recording video

public enum ChallangeMode {
    case none
    case dribble
    case juggling
}



class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let homeCourt =  UIButton(type: .custom)
    let fieldCourt =  UIButton(type: .custom)
    let closeButtonAfterTap = UIButton(type: .custom)
    let closeButton = UIButton(type: .custom)
    var soundPlayer: AVAudioPlayer?
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    let touchView = UIView()
    let touchesLabel = UILabel()
    let timerView = UIView()
    let timerLabel = UILabel()
    let handsOffView = UIView()
    let handsOffLabel = UILabel()
    let gameIsOverView = UIView()
    let saveResultsBtn = UIButton()
    let gameOverLbl = UILabel()
    let humanAndBallDetectionView = UIView()
    var humanAndBallDetectionArea: CGRect?
    var counter = 60
    let ball = UIView()
    var challangeMode: ChallangeMode = .none
    var orientationOfScreen: UIInterfaceOrientationMask!
    var ballXCenterArray = [CGFloat]()
    var detectionOverlay: CALayer! = nil
    var humanArray: [Joint] = []
//    var pointsX: [CGFloat] = []
//    var pointsY: [CGFloat] = []
    var isHumanDetected: Bool = false
    var ballBounds: CGRect?
    var firstSetup: Bool = true
    var poseNet: PoseNet!
    /// The frame the PoseNet model is currently making pose predictions from.
    var currentFrame: CGImage?
    /// The algorithm the controller uses to extract poses from the current frame.
    var algorithm: Algorithm = .single
    /// The set of parameters passed to the pose builder when detecting poses.
    var poseBuilderConfiguration = PoseBuilderConfiguration()
    @IBOutlet weak var previewView: PoseImageView!
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer! = nil
    let videoDataOutput = AVCaptureVideoDataOutput()
    let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var childView: UIHostingController = UIHostingController(rootView: Preview())
    let resultsChallangeView = UIView()
    var homePlace: Bool = true
    
    
    //MARK: Recording video
    var screenRecorder = ScreenRecorder()
    var videoUrl: String!
    var filesDictionary: [String : Int] = UserDefaults.standard.value(forKey: "VideoDictionary") as! [String : Int]
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewView.layer.bounds
    }
    
    func setupUI(){
        previewView.addSubview(touchView)
        touchView.layer.cornerRadius = 10
        touchView.layer.masksToBounds = true
        touchView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
        touchView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        touchView.translatesAutoresizingMaskIntoConstraints = false
        touchView.widthAnchor.constraint(equalToConstant: 110).isActive = true
        touchView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        touchView.leftAnchor.constraint(equalTo: previewView.leftAnchor, constant: 90).isActive = true
        touchView.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 30).isActive = true
        
        touchView.addSubview(touchesLabel)
        touchesLabel.text = "000"
        touchesLabel.font = UIFont(name: "BebasNeue-Bold", size: 52)
        touchesLabel.textColor = UIColor(red: 1, green: 0.908, blue: 0.079, alpha: 1)
        touchesLabel.textAlignment = .center
        touchesLabel.numberOfLines = 0
        touchesLabel.frame = touchView.bounds
        touchesLabel.sizeToFit()
        touchesLabel.adjustsFontSizeToFitWidth = true
        touchesLabel.translatesAutoresizingMaskIntoConstraints = false
        touchesLabel.topAnchor.constraint(greaterThanOrEqualTo: touchView.topAnchor).isActive = true
        touchesLabel.leadingAnchor.constraint(equalTo: touchView.leadingAnchor).isActive = true
        touchesLabel.trailingAnchor.constraint(equalTo: touchView.trailingAnchor).isActive = true
        touchesLabel.bottomAnchor.constraint(equalTo: touchView.bottomAnchor).isActive = true
        touchView.isHidden = true
        
        previewView.addSubview(timerView)
        timerView.layer.cornerRadius = 10
        timerView.layer.masksToBounds = true
        timerView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
        timerView.translatesAutoresizingMaskIntoConstraints = false
        timerView.widthAnchor.constraint(equalToConstant: 140).isActive = true
        timerView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        timerView.rightAnchor.constraint(equalTo: previewView.rightAnchor, constant: -90).isActive = true
        timerView.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 30).isActive = true
        timerView.addSubview(timerLabel)
        timerLabel.text = "01:00"
        timerLabel.font = UIFont(name: "BebasNeue-Bold", size: 52)
        timerLabel.textAlignment = .center
        timerLabel.numberOfLines = 0
        timerLabel.frame = touchView.bounds
        timerLabel.textColor = UIColor.white
        timerLabel.sizeToFit()
        timerLabel.adjustsFontSizeToFitWidth = true
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.topAnchor.constraint(greaterThanOrEqualTo: timerView.topAnchor).isActive = true
        timerLabel.leadingAnchor.constraint(equalTo: timerView.leadingAnchor).isActive = true
        timerLabel.trailingAnchor.constraint(equalTo: timerView.trailingAnchor).isActive = true
        timerLabel.bottomAnchor.constraint(equalTo: timerView.bottomAnchor).isActive = true
        timerView.isHidden = true
        
        previewView.addSubview(humanAndBallDetectionView)
        humanAndBallDetectionView.layer.masksToBounds = true
        humanAndBallDetectionView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        humanAndBallDetectionView.frame = CGRect(x: 0, y: 0, width: previewView.frame.width, height: previewView.frame.height)
        
        humanAndBallDetectionArea = CGRect(x: previewView.frame.width - (previewView.frame.width - touchView.frame.width - 20) + 10, y: 20, width: UIScreen.screens.first!.bounds.width - 20 - (100 + touchView.frame.width*2 + 40), height: previewView.frame.height-30)
        
        
        humanAndBallDetectionView.autoresizesSubviews = true
        let backImage = UIImageView(frame: previewView.frame)
        humanAndBallDetectionView.addSubview(backImage)
        backImage.layer.masksToBounds = true
        backImage.image = UIImage(named: "background_challange")
        backImage.contentMode = .scaleAspectFit
        backImage.translatesAutoresizingMaskIntoConstraints = false
        backImage.widthAnchor.constraint(equalToConstant: (UIScreen.screens.first?.bounds.width)!).isActive = true
        backImage.heightAnchor.constraint(equalToConstant: previewView.frame.height).isActive = true
        backImage.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 0).isActive = true
        backImage.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 0).isActive = true
        backImage.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 0).isActive = true
        backImage.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: 0).isActive = true
        
        
        
        humanAndBallDetectionView.addSubview(closeButton)
        closeButton.setImage(UIImage(named: "close_button_dribbling"), for: .normal)
        closeButton.contentHorizontalAlignment = .fill
        closeButton.contentVerticalAlignment = .fill
        closeButton.imageView?.contentMode = .scaleAspectFill
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.rightAnchor.constraint(equalTo: previewView.rightAnchor, constant: -56).isActive = true
        closeButton.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 35).isActive = true
        closeButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
        closeButton.addTarget(self, action: #selector(dismissFunction), for: .touchUpInside)
        
        
        humanAndBallDetectionView.addSubview(homeCourt)
        if homePlace {
            homeCourt.setImage(UIImage(named: "home_court_choosed"), for: .normal)
        }
        homeCourt.contentHorizontalAlignment = .fill
        homeCourt.contentVerticalAlignment = .fill
        homeCourt.imageView?.contentMode = .scaleAspectFill
        homeCourt.translatesAutoresizingMaskIntoConstraints = false
        homeCourt.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 56).isActive = true
        homeCourt.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 35).isActive = true
        homeCourt.widthAnchor.constraint(equalToConstant: 60).isActive = true
        homeCourt.heightAnchor.constraint(equalToConstant: 60).isActive = true
        homeCourt.addTarget(self, action: #selector(choosingHomePlace), for: .touchUpInside)
        
        
        humanAndBallDetectionView.addSubview(fieldCourt)
        fieldCourt.setImage(UIImage(named: "field_court"), for: .normal)
        fieldCourt.contentHorizontalAlignment = .fill
        fieldCourt.contentVerticalAlignment = .fill
        fieldCourt.imageView?.contentMode = .scaleAspectFill
        fieldCourt.translatesAutoresizingMaskIntoConstraints = false
        fieldCourt.leadingAnchor.constraint(equalTo: homeCourt.trailingAnchor, constant: 20).isActive = true
        fieldCourt.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 35).isActive = true
        fieldCourt.widthAnchor.constraint(equalToConstant: 60).isActive = true
        fieldCourt.heightAnchor.constraint(equalToConstant: 60).isActive = true
        fieldCourt.addTarget(self, action: #selector(choosingCourtPlace), for: .touchUpInside)
        
        
        previewView.addSubview(closeButtonAfterTap)
        closeButtonAfterTap.setImage(UIImage(named: "close_button_dribbling"), for: .normal)
        closeButtonAfterTap.contentHorizontalAlignment = .fill
        closeButtonAfterTap.contentVerticalAlignment = .fill
        closeButtonAfterTap.imageView?.contentMode = .scaleAspectFill
        closeButtonAfterTap.translatesAutoresizingMaskIntoConstraints = false
        closeButtonAfterTap.rightAnchor.constraint(equalTo: previewView.rightAnchor, constant: -56).isActive = true
        closeButtonAfterTap.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -35).isActive = true
        closeButtonAfterTap.widthAnchor.constraint(equalToConstant: 60).isActive = true
        closeButtonAfterTap.heightAnchor.constraint(equalToConstant: 60).isActive = true
        closeButtonAfterTap.addTarget(self, action: #selector(dismissFunction), for: .touchUpInside)
        closeButtonAfterTap.isHidden = true
        
        
        
        let firstRuleLabel = UILabel()
        humanAndBallDetectionView.addSubview(firstRuleLabel)
        firstRuleLabel.text = "Поставь телефон\nна пол"
        firstRuleLabel.font = UIFont(name: "SF Pro Display", size: 16)
        firstRuleLabel.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        firstRuleLabel.textAlignment = .center
        firstRuleLabel.numberOfLines = 3
        firstRuleLabel.frame = touchView.bounds
        firstRuleLabel.sizeToFit()
        firstRuleLabel.adjustsFontSizeToFitWidth = true
        firstRuleLabel.translatesAutoresizingMaskIntoConstraints = false
        firstRuleLabel.bottomAnchor.constraint(equalTo: humanAndBallDetectionView.bottomAnchor, constant: -50).isActive = true
        
        firstRuleLabel.leadingAnchor.constraint(equalTo: touchView.leadingAnchor).isActive = true
        
        let secondRuleLabel = UILabel()
        humanAndBallDetectionView.addSubview(secondRuleLabel)
        secondRuleLabel.text = "Отойди на расстояние\n2-3 метра от телефона"
        secondRuleLabel.font = UIFont(name: "SF Pro Display", size: 16)
        secondRuleLabel.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        secondRuleLabel.textAlignment = .center
        secondRuleLabel.numberOfLines = 3
        secondRuleLabel.frame = touchView.bounds
        secondRuleLabel.sizeToFit()
        secondRuleLabel.adjustsFontSizeToFitWidth = true
        secondRuleLabel.translatesAutoresizingMaskIntoConstraints = false
        secondRuleLabel.bottomAnchor.constraint(equalTo: humanAndBallDetectionView.bottomAnchor, constant: -50).isActive = true
        
        secondRuleLabel.trailingAnchor.constraint(equalTo: closeButton.trailingAnchor).isActive = true
        
        
        //MARK: Hands Off Functionality UI
        previewView.addSubview(handsOffView)
        handsOffView.layer.masksToBounds = true
        handsOffView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
        handsOffView.frame = CGRect(x: 0, y: 0, width: previewView.frame.width, height: previewView.frame.height)

        let handsOffImage = UIImageView()
        handsOffView.addSubview(handsOffImage)
        handsOffImage.image = UIImage(named: "hands_off")
        handsOffImage.contentMode = .scaleAspectFit
        handsOffImage.translatesAutoresizingMaskIntoConstraints = false
        handsOffImage.centerXAnchor.constraint(equalTo: handsOffView.centerXAnchor).isActive = true
        handsOffImage.centerYAnchor.constraint(equalTo: handsOffView.centerYAnchor).isActive = true
        handsOffImage.topAnchor.constraint(equalTo: handsOffView.topAnchor, constant: 50).isActive = true
        handsOffImage.bottomAnchor.constraint(equalTo: handsOffView.bottomAnchor, constant: -50).isActive = true
        handsOffImage.leadingAnchor.constraint(equalTo: handsOffView.leadingAnchor, constant: 50).isActive = true
        handsOffImage.trailingAnchor.constraint(equalTo: handsOffView.trailingAnchor, constant: -50).isActive = true
        handsOffView.isHidden = true
    }
    
    //MARK: Function for SoundPlaying
    func playSound(sound: String, back: Bool) {
        if back {
            DispatchQueue.global(qos: .utility).async {
                let path = Bundle.main.path(forResource: sound, ofType:nil)!
                let url = URL(fileURLWithPath: path)
                do {
                    self.soundPlayer = try AVAudioPlayer(contentsOf: url)
                    self.soundPlayer?.play()
                } catch {
                    print("Sound Unavailable")
                }
            }
        } else {
            let path = Bundle.main.path(forResource: sound, ofType:nil)!
            let url = URL(fileURLWithPath: path)
            do {
                self.soundPlayer = try AVAudioPlayer(contentsOf: url)
                self.soundPlayer?.play()
            } catch {
                print("Sound Unavailable")
            }
        }
        
    }
    
    
    @objc func choosingHomePlace() {
        homePlace = true
        homeCourt.setImage(UIImage(named: "home_court_choosed"), for: .normal)
        fieldCourt.setImage(UIImage(named: "field_court"), for: .normal)
    }
    
    @objc func choosingCourtPlace() {
        homePlace = false
        homeCourt.setImage(UIImage(named: "home_court"), for: .normal)
        fieldCourt.setImage(UIImage(named: "field_court_choosed"), for: .normal)
    }
    
    
    @objc func timerAction() {
        if counter > 0 {
            counter -= 1
            playSound(sound: "tik.mp3", back: true)
            let formatedTimer = timeFormatted(counter)
            timerLabel.text = formatedTimer
        } else {
            //Stop Video Here
            stopTimer()
            session.stopRunning()
            saveVideo(save: true)
            let points = Int(touchesLabel.text ?? "0")
            let userSave = UserMod()
            let returnValue = UserDefaults.standard.string(forKey: "now_user")
            UserDefaults.standard.set(points!, forKey: "points")
            userSave.updateUserChallange(name: returnValue ?? "", challange: points!)
            UserDefaults.standard.synchronize()
            showChallangeResults(score: points ?? 0)
        }
    }
    
    
    private func showChallangeResults(score: Int) {
        var mainTitle: String?
        var mainColor: UIColor?
        var close_btn: String?
        var repeat_btn: String?
        if challangeMode == ChallangeMode.dribble {
            mainTitle = "КОНТРОЛЬ И ДРИБЛИНГ"
            mainColor = UIColor(red: 1, green: 0.908, blue: 0.079, alpha: 1)
            close_btn = "close_button_dribbling"
            repeat_btn = "repeat_dribbling"
            
        } else {
            mainTitle = "ЧЕКАНКА"
            mainColor = UIColor(red: 0.482, green: 0.894, blue: 0.584, alpha: 1)
            close_btn = "close_button_juggling"
            repeat_btn = "repeat_juggling"
        }
        self.previewView.frame = self.view.frame
        childView = UIHostingController(rootView: Preview(close_btn: close_btn, restart_btn: repeat_btn, totalScore: score, bestResult: true, challangeMode: challangeMode, mainTitle: mainTitle, rewardBage: "best", mainColor: mainColor, videoUrl: self.videoUrl, restartChallange: restartChallange, dismissAction: dismissFunction))
        self.previewView.addSubview(resultsChallangeView)
        resultsChallangeView.frame = previewView.frame
        childView.view.backgroundColor = .black
        self.resultsChallangeView.addSubview(childView.view)
        childView.view.frame = self.view.frame
        childView.didMove(toParent: self)
    }
    
    
    func restartChallange(){
        resultsChallangeView.isHidden = true
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    func dismissFunctionFromChallangeResults(){
        self.presentingViewController?.dismiss(animated: false, completion: nil)
        self.presentingViewController?.dismiss(animated: false, completion: {
            AppDelegate.orientationLock = UIInterfaceOrientationMask.portrait
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        })
    }
    
    func startTimer() {
        guard timer == nil else {return}
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func saveVideo(save: Bool){
        DispatchQueue.global(qos: .background).async { [self] in
            if screenRecorder.recorder.isRecording {
                screenRecorder.stoprecording(errorHandler: { error in
                    debugPrint("Error when stop recording \(error)")
                })
            }
        }
        if save {
        if let url = videoUrl {
            filesDictionary[url] = Int(touchesLabel.text ?? "0")
            UserDefaults.standard.setValue(filesDictionary, forKey: "VideoDictionary")
            UserDefaults.standard.synchronize()
            print("Video URLS SAVED \(UserDefaults.standard.value(forKey: "VideoDictionary"))")
        }
        }
    }
    
    @objc func dismissFunction(){
        stopTimer()
        session.stopRunning()
        saveVideo(save: false)
        self.presentingViewController?.dismiss(animated: true, completion: nil)
        self.presentingViewController?.dismiss(animated: true, completion: {
            AppDelegate.orientationLock = UIInterfaceOrientationMask.portrait
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        })
    }
    
    private func timeFormatted(_ totalSeconds: Int) -> String {
        let seconds: Int = totalSeconds % 60
        let minutes: Int = (totalSeconds / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        let deviceType = UIDevice().type.rawValue
        let devicesArray = ["iPhone 11","iPhone 11 Pro","iPhone 11 Pro Max","iPhone SE 2nd gen", "iPhone 12 Mini", "iPhone 12","iPhone 12 Pro", "iPhone 12 Mini","iPhone 12","iPhone 12 Pro", "iPhone 12 Pro Max", "iPhone 7 Plus", "iPhone XS"]
        if devicesArray.contains(deviceType) {
            //            session.sessionPreset = .hd4K3840x2160
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .hd1920x1080
        }
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.height)
            bufferSize.height = CGFloat(dimensions.width)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer.connection?.isVideoMirrored = true
        if devicesArray.contains(deviceType) {
            previewLayer.connection?.videoOrientation = .landscapeLeft
        } else {
            previewLayer.connection?.videoOrientation = .landscapeRight
        }
        //        rootLayer = previewView.layer
        previewLayer.frame = previewView.layer.bounds
        previewView.layer.addSublayer(previewLayer)
    }
    
    func startCaptureSession() {
        session.startRunning()
    }
    
    // Clean up capture setup
    private func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    //Realized in subclass
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // to be implemented in the subclass
    }
    
    //Realized in subclass
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let exifOrientation: CGImagePropertyOrientation
        if orientationOfScreen == UIInterfaceOrientationMask.landscapeLeft {
            exifOrientation = .leftMirrored
        } else {
            exifOrientation = .rightMirrored
        }
        return exifOrientation
    }
}

extension VisionObjectRecognitionViewController: PoseNetDelegate {
    
    internal func poseNet(_ poseNet: PoseNet, didPredict predictions: PoseNetOutput) {
        defer {
            self.currentFrame = nil
        }
        guard let currentFrame = currentFrame else {
            return
        }
        
        let poseBuilder = PoseBuilder(output: predictions,configuration: poseBuilderConfiguration, inputImage: currentFrame)
        //        let poses = [poseBuilder.pose]
        var arrayOfJoints:[Joint] = []
        
        
        for i in [poseBuilder.pose] {
            let array = i.joints
            for j in array {
                let position = CGPoint(x: j.value.position.y, y:  0.0 + (bufferSize.height - j.value.position.x))
                //MARK: Check confiedence of the joints for reduce duplicate points
                if j.value.confidence > 0.6 {
                    let joint = Joint(name: j.value.name, cell: j.value.cell, position: position, confidence: j.value.confidence, isValid: true)
                    arrayOfJoints.append(joint)
                }
            }
        }
        humanArray = arrayOfJoints
        if humanArray.count > 12 && !isHumanDetected {
            isHumanDetected = true
        }
        if isHumanDetected && !firstSetup  {
            if  challangeMode == .dribble {
                checkArmsWithBall(joints: humanArray,distance: 0)
            }
//            else {
//                checkArmsWithBall(joints: humanArray,distance: 5)
//            }
            
        }
        
        if firstSetup && challangeMode == .juggling {
            detectJugglingLineHeight(joints: humanArray)
        }
    }
    
    private func checkJointsWithFrame(joints:[Joint]) -> Bool {
        let frame = previewLayer.convert(self.humanAndBallDetectionArea!, to: detectionOverlay)
        var positions: [CGPoint] = []
        for joint in joints {
            positions.append(joint.position)
        }
        let result = positions.allSatisfy({frame.contains($0)})
        return result
    }
    
    private func detectJugglingLineHeight(joints:[Joint]) {
        if let ballPosition = ballBounds {
            for joint in joints {
                if (joint.name == .leftKnee || joint.name == .rightKnee ) && joint.confidence > 0.6 {
                    print("Knee coordinates \((joint.position.x,joint.position.y))")
                    kneesLevel = joint.position.x
                } else if (joint.name == .leftShoulder || joint.name == .rightShoulder ) && joint.confidence > 0.6 {
                    
                    shoulderLevel = joint.position.x
                }
            }
        }}
    
    
    
    private func checkArmsWithBall(joints:[Joint], distance: CGFloat) {
        if let ballPosition = ballBounds {
            for joint in joints {
                if (joint.name == .leftWrist || joint.name == .rightWrist ) && joint.confidence > 0.8 {
                    let rectOfHand = CGRect(x: joint.position.x, y: joint.position.y, width: 50, height: 50)
                    if ballPosition.midY >= rectOfHand.minY - distance && ballPosition.midY <= rectOfHand.maxY + distance && ballPosition.midX >= rectOfHand.minX - distance &&
                        ballPosition.midX <= rectOfHand.maxX + distance  {
                        handsOffView.alpha = 1
                        handsOffView.isHidden = false
//                        print("Touch the point \(joint.name.rawValue)")
                        UIView.animate(withDuration: 1.0, animations: {
                            self.handsOffView.alpha = 0
                        }) { (finished) in
                            self.handsOffView.isHidden = finished
                        }
                        
                    }
                }
                
            }
        }
    }
}




