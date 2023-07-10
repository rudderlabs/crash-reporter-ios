//
//  ViewController.swift
//  SampleSwift
//
//  Created by Pallab Maiti on 19/06/23.
//

import UIKit
import MetricsReporter

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func onButtonTap(_ button: UIButton) {
        CrashReporterClient.shared.testCrash()
        
        
//        let arr: NSMutableArray = NSMutableArray()
//        _ = arr.object(at: 5)
    }
}

