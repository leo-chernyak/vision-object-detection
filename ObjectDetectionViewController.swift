//
//  ObjectDetectionViewController.swift
//  Object Detection Live Stream
//
//  Created by Alexey Korotkov on 6/25/19.
//  Copyright © 2019 Alexey Korotkov. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import AudioToolbox
import CoreVideo
import VideoToolbox
import Photos

@available(iOS 14.0, *)
final class VisionObjectRecognitionViewController: ViewController, CAAnimationDelegate {
    
    
    //Dribbling values
    private var changeValue: CGFloat = 400
    private var touches: Int = 0
    private var pointLevelFirst: CGFloat?
    private var touchPointLayer: CAShapeLayer = CAShapeLayer()
    private var touchPointDownloadingLayer: CAShapeLayer = CAShapeLayer()
    private var trackLayer: CAShapeLayer = CAShapeLayer()
    
    
    //Juggling values
    private var juggleLine: CAShapeLayer = CAShapeLayer()
    private var juggleBool: Bool! = false
    private var lastTouchBallCoordinate: CGFloat?
    private var touchPointCoordinate: CGFloat = 400.0
    
    // Vision parts
    private var requests = [VNRequest]()
    private var humanBodyRequest = VNDetectHumanBodyPoseRequest()
    
    
    //Other values
    lazy var kneesLevel: CGFloat = CGFloat()
    lazy var shoulderLevel: CGFloat = CGFloat()
    let basicAnimation = CABasicAnimation(keyPath: "strokeEnd")
    private var counterForBallStoping: Int = 0
    var newTouchPoint = false
//    var regionOfInterest: CGRect = CGRect()
    
    
    let requestHandler = VNSequenceRequestHandler()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("The mode is \(challangeMode)")
        AppDelegate.orientationLock = orientationOfScreenMask
        UIDevice.current.setValue(orientation, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
        UIApplication.shared.isIdleTimerDisabled = true
        basicAnimation.toValue = 1
        basicAnimation.duration = 4
        basicAnimation.fillMode = .forwards
        basicAnimation.isRemovedOnCompletion = false
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        basicAnimation.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if screenRecorder.recorder.isAvailable {
            print("And We start recording")
            let suffix = createURLforVideo()
            let url = FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask).first!.appendingPathComponent("\(suffix).mp4")
            self.videoUrl = url.absoluteString
            print("Here is video URL\(url)")
            screenRecorder.startRecording(to: url,
                                          size: nil,
                                          saveToCameraRoll: false,
                                          errorHandler: { error in
                                            debugPrint("Error when recording \(error)")
                                          })
        }
        do {
            self.poseNet = try PoseNet()
        } catch {
            fatalError("Failed to load model. \(error.localizedDescription)")
        }
        self.poseNet.delegate = self
        self.setupAVCapture()
        self.setupUI()
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if closeButtonAfterTap.isHidden && humanAndBallDetectionView.isHidden {
            closeButtonAfterTap.isHidden = false
        } else if !closeButtonAfterTap.isHidden && humanAndBallDetectionView.isHidden  {
            closeButtonAfterTap.isHidden = true
        }
    }
    
    func animationDidStart(_ anim: CAAnimation) {
//        print("Start Animation")
        
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//        print("End Animation \(flag)")
        DispatchQueue.global(qos: .background).async {
            self.newTouchPoint = flag
        }
    }
    
    @discardableResult
    private func setupVision() -> NSError? {
        // Setup Vision parts
        let error: NSError! = nil
        guard let modelURL = Bundle.main.url(forResource: "SoccerBall3.0", withExtension: "mlmodelc") else {
            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        do {
            
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.drawVisionRequestResults(results)
                    }
                })
            })
            objectRecognition.imageCropAndScaleOption = .scaleFill
            
            
            requests = [objectRecognition]
            
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        
        return error
    }
    

    
    private func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        if let layers = detectionOverlay.sublayers {
            for layer in layers {
                if layer.name != "TouchPoint"  {
                    if layer.name != "JugglingLine" {
                        layer.removeFromSuperlayer()
                    }
                }
            }
        }
        
        // check for animation status
        if newTouchPoint {
            changeTouchPointPos(ballPosition: CGRect())
            newTouchPoint = false
        }
        
        //MARK: Uncomment to see humans-points
        
//        for joint in humanArray {
            //                    let humanPoint = self.createHumanPoint(CGRect(x: joint.position.x, y:joint.position.y, width: 20, height: 20))
            //                    humanPoint.cornerRadius = 10
            //                    detectionOverlay.addSublayer(humanPoint)
//        }
//        makeHumanRectangle(pointsX: pointsX, pointsY: pointsY)
        
        
        
        // x - height of the ball
        // width and height = ballBounds
        // y - random or some random space from the ball


        
        
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            
            
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            let frame = previewLayer.convert(self.humanAndBallDetectionArea!, to: detectionOverlay)
            let rangeX = frame.minX ... frame.maxX
            let rangeY = frame.minY ... frame.maxY
            let frameLimit = (frame.maxX/3)*2
            
            var maximumSizeOfBall: CGFloat!
            var pointWidth: CGFloat!
            if bufferSize.height > 3800 {
                maximumSizeOfBall = 300
                pointWidth = 300
            } else {
                maximumSizeOfBall = 160
                pointWidth = 160
            }
            
            //MARK: First Setting Up (add touchpointLayer with foot Joint)
            if topLabelObservation.identifier == "ball" && objectBounds.width < maximumSizeOfBall && objectBounds.midX > frameLimit && firstSetup && rangeX.contains(objectBounds.midX) && rangeY.contains(objectBounds.midY) && isHumanDetected {
                startTimer()
                
                //MARK: Check is point outside the screen
                //                pointLevelFirst = objectBounds.minX + (objectBounds.midX - objectBounds.minX)
                if challangeMode == ChallangeMode.juggling {
                    var juggleHeight: CGFloat!
                    juggleHeight = kneesLevel - 50
                    print("Height of juggline \(juggleHeight)")
//                    if juggleHeight > 880 || juggleHeight > 440{
//                        juggleHeight = 530
//                    }
//                    juggleHeight = 600
                    juggleLine = createJugglingLine(CGRect(x: juggleHeight, y: 0, width: 20, height: 1920))
                    detectionOverlay.addSublayer(juggleLine)
                } else if challangeMode == ChallangeMode.dribble {
                    pointLevelFirst = 880
                    touchPointLayer = createTouchPointRectLayerWithBounds(CGRect(x: pointLevelFirst!, y: objectBounds.midY - objectBounds.width/2, width: pointWidth, height: pointWidth))
                    //
                    touchPointLayer.cornerRadius = pointWidth/2
                    detectionOverlay.addSublayer(touchPointLayer)
                }
                
                
                firstSetup = false
                humanAndBallDetectionView.isHidden = true
                touchView.isHidden = false
                timerView.isHidden = false
            }
            //Dribbling mode
            var ballLayer: CALayer!
            ballBounds = objectBounds
            
            if topLabelObservation.identifier == "ball"  && objectBounds.width < 250 && objectBounds.minX > shoulderLevel {
                ballLayer = createBallLayer(objectBounds, color: .green)
                ballLayer!.backgroundColor = UIColor.white.withAlphaComponent(0.8).cgColor
                detectionOverlay.addSublayer(ballLayer!)
            }
            
            if self.challangeMode == .dribble {
                if let ballBounds = ballBounds {
                    if ballBounds.midY >= touchPointLayer.frame.minY - 20 && ballBounds.midY <= touchPointLayer.frame.maxY + 20 && ballBounds.midX >= touchPointLayer.frame.minX - 20 &&
                        ballBounds.midX <= touchPointLayer.frame.maxX + 20 && self.handsOffView.isHidden {
                        counterForBallStoping += 1
                        if counterForBallStoping == 4 {
                            playSound(sound: "touch_sound2.mp3", back: false)
                            touches += 1
                            counterForBallStoping = 0
                            changeTouchPointPos(ballPosition: ballBounds)
                        }
                    }
                }
            } else if challangeMode == .juggling {
                if let ballPosition = ballBounds {
                    if !juggleBool {
                        //MARK: Juggling Mode
                        if (ballPosition.minX < juggleLine.frame.maxX) && ballPosition.minX > shoulderLevel && humanArray.count > 8 {
                            juggleBool = true
                            touches += 1
                        }
                    } else if (ballPosition.minX > juggleLine.frame.maxX) && ballPosition.minX > shoulderLevel && humanArray.count > 8 {
                        juggleBool = false
                    }
                }
            }
        }
        self.touchesLabel.text = String(touches)
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    //MARK: Function change touch point position randomly
    private func changeTouchPointPos(ballPosition: CGRect){
        touchPointLayer.removeAllAnimations()
        lastTouchBallCoordinate = ballPosition.midY
        
        //Desicion two
        
        let levelOne = [100,300,500,700,900,1100,1300,1500,1700,1800]
        let levelTwo = [250,450,650,850,1050,1250,1450,1650]
        var level: [Int]!
        if homePlace {
            level = levelTwo
        } else {
            level = levelOne
        }
        
        var random = CGFloat(level.randomElement()!)
        while random == touchPointCoordinate - 200 || random == touchPointCoordinate + 200 || random == touchPointCoordinate {
            random = CGFloat(level.randomElement()!)
        }
        
        touchPointCoordinate = random
        
        //left size should be more than 150
        //right size should be less than 1800
        
        if let floorLevel = pointLevelFirst {
            touchPointLayer.position = CGPoint(x: floorLevel, y: touchPointCoordinate)
        }
        touchPointDownloadingLayer.add(basicAnimation, forKey: "urSoBasic")
    }
    
    
    
    
    //MARK: Functions for Video Output
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        //MARK: Human Detection
        var image: CGImage?
        // Create a Core Graphics bitmap image from the pixel buffer.
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        // Release the image buffer.
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        currentFrame = image
        DispatchQueue.global(qos: .background).async {
            
            self.poseNet.predict(image!)
        }
        
        //MARK: Ball Detection
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        do {
            try requestHandler.perform(self.requests, on: pixelBuffer, orientation: exifOrientation)
           } catch {
            print("Tracking failed.")
           }
    }
    
    override func setupAVCapture() {
        super.setupAVCapture()
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        DispatchQueue.global(qos: .background).async {
            self.setupVision()
        }
        // start the capture
        startCaptureSession()
        
    }
    
    //MARK: Functions for drawing Layers
    private func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: previewView.layer.bounds.midX, y: previewView.layer.bounds.midY)
        previewView.layer.addSublayer(detectionOverlay)
    }
    
    private func updateLayerGeometry() {
        
        let bounds = self.previewView.layer.bounds
        var scale: CGFloat
        let xScale: CGFloat = bounds.size.width / self.bufferSize.height
        let yScale: CGFloat = bounds.size.height / self.bufferSize.width
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        self.detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
        
        
    }
    
    private func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10 , height: bounds.size.width - 10 )
        textLayer.position = CGPoint(x: bounds.midX , y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    
    private func createTouchPointRectLayerWithBounds(_ bounds: CGRect) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.bounds = bounds
        //        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.position = CGPoint(x: bounds.minX, y: bounds.midY)
        shapeLayer.name = "TouchPoint"
        shapeLayer.backgroundColor = UIColor(red: 1, green: 0.908, blue: 0.079, alpha: 1).cgColor
        shapeLayer.cornerRadius = 7
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let circularPath = UIBezierPath(arcCenter: center, radius: bounds.width/2, startAngle: CGFloat.pi, endAngle: -CGFloat.pi, clockwise: false)
        trackLayer.path = circularPath.cgPath
        trackLayer.strokeColor = UIColor(red: 0.114, green: 0.412, blue: 0.322, alpha: 1).cgColor
        trackLayer.lineWidth = 25
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineCap = CAShapeLayerLineCap.round
        touchPointDownloadingLayer.path = circularPath.cgPath
        touchPointDownloadingLayer.strokeColor =  UIColor.white.cgColor
        touchPointDownloadingLayer.lineWidth = 25
        touchPointDownloadingLayer.fillColor = UIColor(red: 1, green: 0.908, blue: 0.079, alpha: 1).cgColor
        touchPointDownloadingLayer.lineCap = CAShapeLayerLineCap.round
        touchPointDownloadingLayer.strokeEnd = 0
        
        trackLayer.addSublayer(touchPointDownloadingLayer)
        shapeLayer.addSublayer(trackLayer)
        return shapeLayer
    }
    
    private func createJugglingLine(_ bounds: CGRect) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "JugglingLine"
        shapeLayer.backgroundColor = UIColor.clear.cgColor
        shapeLayer.cornerRadius = 10
        shapeLayer.strokeColor = UIColor(red: 1, green: 0.908, blue: 0.079, alpha: 1).cgColor
        shapeLayer.lineDashPattern = [70, 32]
        shapeLayer.lineWidth = 20
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX - bounds.width, y: bounds.maxY)])
        shapeLayer.path = path
        return shapeLayer
    }
    
    private func createHumanPoint(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "HumanPoint"
        shapeLayer.backgroundColor = UIColor(red: 1, green: 0.908, blue: 0.079, alpha: 1).cgColor
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    private func createBallLayer(_ bounds: CGRect, color: UIColor) -> CALayer {
        if bounds.size.width > bounds.size.height {
            let radius: CGFloat = bounds.size.width / 2
            let increment = bounds.size.width / 2 - bounds.size.height / 2
            let path = UIBezierPath(roundedRect: CGRect(x: bounds.origin.x - 5, y: bounds.origin.y - 5 - increment, width: radius * 2 + 10, height: radius * 2 + 10), cornerRadius: radius + 5)
            let circlePath = UIBezierPath(roundedRect: CGRect(x: bounds.origin.x + 5, y: bounds.origin.y - increment + 5, width: radius * 2 - 10, height: radius * 2 - 10), cornerRadius: radius - 5)
            path.append(circlePath)
            path.usesEvenOddFillRule = true
            let fillLayer = CAShapeLayer()
            fillLayer.path = path.cgPath
            fillLayer.fillRule = .evenOdd
            fillLayer.fillColor = color.cgColor
            fillLayer.opacity = 0.5
            return fillLayer
        } else {
            let radius: CGFloat = bounds.size.height / 2
            
            let increment = bounds.size.height / 2 - bounds.size.width / 2
            
            let path = UIBezierPath(roundedRect: CGRect(x: bounds.origin.x - 5 - increment, y: bounds.origin.y - 5, width: radius * 2 + 10, height: radius * 2 + 10), cornerRadius: radius + 5)
            let circlePath = UIBezierPath(roundedRect: CGRect(x: bounds.origin.x + 5 - increment, y: bounds.origin.y + 5, width: radius * 2 - 10, height: radius * 2 - 10), cornerRadius: radius - 5)
            path.append(circlePath)
            path.usesEvenOddFillRule = true
            
            let fillLayer = CAShapeLayer()
            fillLayer.path = path.cgPath
            fillLayer.fillRule = .evenOdd
            fillLayer.fillColor = color.cgColor
            fillLayer.opacity = 0.5
            return fillLayer
        }
    }
    
    //MARK: Functions for Video Recording
    private func createURLforVideo() -> String {
        var urlSuffix: String = getDate()
        if challangeMode == ChallangeMode.dribble {
            urlSuffix.append(" - dribble")
        } else {
            urlSuffix.append(" - juggling")
        }
        return urlSuffix
    }
    
    
    private func getDate()->String{
        let time = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
        let stringDate = timeFormatter.string(from: time)
        return stringDate
    }
}

extension CAShapeLayer {
    class func performWithoutAnimation(_ actionsWithoutAnimation: () -> Void){
        CATransaction.begin()
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        actionsWithoutAnimation()
        CATransaction.commit()
    }
}
