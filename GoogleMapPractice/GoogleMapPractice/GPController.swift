//
//  GPController.swift
//  GoogleMapPractice
//
//  Created by 楊敦富 on 2018/11/16.
//  Copyright © 2018年 楊敦富. All rights reserved.
//

import UIKit
import GoogleMaps

class GPController: UIViewController , GMSMapViewDelegate , UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storedPositions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: tableviewcellName, for: indexPath)
        cell.textLabel?.lineBreakMode = .byTruncatingHead
        if indexPath.row < storedPositions.count{
            cell.textLabel?.text = storedPositions[indexPath.row].1
        }else{
            cell.textLabel?.text = "Not on the Map"
        }
        return cell
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            self.storedPositions[indexPath.row].2.map = nil
            self.storedPositions.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    //Gesture tap event
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        
        
        let reverseGeoCoder = GMSGeocoder()
        reverseGeoCoder.reverseGeocodeCoordinate(coordinate, completionHandler: {(placeMark, error) -> Void in
            if error == nil {
                if let placeMarkObject = placeMark,
                    let count = placeMarkObject.results()?.count,
                    count > 0,
                    let pl = placeMarkObject.firstResult()?.lines{
                    
                    let foo = (coordinate,pl.count > 0 ? pl[(pl.count - 1 )] : "")
                    //self.StoredPositions.append(foo)
                    self.clickPosition = foo
                    self.tapAddressName?.text = foo.1
                }
            }
            
        })
    }

    @IBOutlet weak var smallview: UIView!
    @IBOutlet weak var tapAddressName: UILabel!
    @IBOutlet weak var tableview: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        loadGoogleMap()
        smallview.backgroundColor = UIColor.blue
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: tableviewcellName)
        tableview.dataSource = self
        tableview.delegate = self
        // Do any additional setup after loading the view.
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //Because the view build from Stroy Board
        //It is useless changing the frame before viewDidiAppear()...
        gpView!.center  = smallview.center
        gpView!.frame = smallview.bounds
    }
    var camera : GMSCameraPosition?
    var gpView : GMSMapView?
    

    var storedPositions = [(CLLocationCoordinate2D,String, GMSMarker )]()
    var clickPosition : (CLLocationCoordinate2D,String)?
    let tableviewcellName = "MMMCell"
    
    
    func loadGoogleMap(){
        
        //元智大學 YZU edu
        let yzu_latitude = 24.970231
        let yzu_longitude = 121.263465
        
        camera = GMSCameraPosition.camera(withLatitude: yzu_latitude, longitude: yzu_longitude, zoom: 17.0)
        gpView = GMSMapView.map(withFrame: CGRect.zero, camera: camera!)
        smallview.addSubview(gpView!)
        
        gpView?.delegate = self
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: yzu_latitude, longitude: yzu_longitude)
        //Taiwan
        marker.title = "台灣"
        //YZU
        marker.snippet = "元智大學"
        marker.map = gpView
        
        let pos = CLLocationCoordinate2D(latitude: yzu_latitude, longitude: yzu_longitude)
        let name = "元智大學"
        storedPositions.append((pos, name, marker))
    }

    @IBAction func CalculateRoute(_ sender: UIButton) {
        if storedPositions.count < 3 {
            //too few waypoints, At least 3 markers
            ShowAlert(title: "標註點過少", message: "標註點必須至少三個")
            return
        }else if storedPositions.count > 9 {
            //too many waypoints; At most 9 waypoints for google direction api in free mode.
            ShowAlert(title: "標註點過多", message: "免費版本的Google Map Api僅提供最多9組標註點規劃路線")
        }
        ShowAlert(title: "注意", message:
            //Google direction api allows you use one request per day if you do not have any credit card in the account
            "此功能需要網路，並且不會立刻顯示在地圖上，並且一天只能一次")
        SendRouteRequest()
    }
    
    func SendRouteRequest(){
        //https://maps.googleapis.com/maps/api/directions/json
        var urlbasic = URLComponents()
        urlbasic.scheme = "https"
        urlbasic.host = "maps.googleapis.com"
        urlbasic.path = "/maps/api/directions/json"
        
        //for swift, use URLQueryItem instead of NS...
        var queryitems = [URLQueryItem]()
        var foo = ""
        for i in 1..<(storedPositions.count - 1){
            foo += "\(storedPositions[i].0.latitude),\(storedPositions[i].0.longitude)"
            if i != (storedPositions.count - 2){
                foo += "|"
            }
        }
        
        
        let waypoints = URLQueryItem(name: "waypoints", value: foo)
        let origin = URLQueryItem(name: "origin", value: "\(storedPositions[0].0.latitude),\(storedPositions[0].0.longitude)")
        let destination = URLQueryItem(name: "destination", value: "\(storedPositions[(storedPositions.count - 1 )].0.latitude),\(storedPositions[(storedPositions.count - 1 )].0.longitude)")
        let key = URLQueryItem(name: "key", value: "YOURAPIKEY")
        queryitems.append(origin)
        queryitems.append(destination)
        queryitems.append(waypoints)
        queryitems.append(key)
        urlbasic.queryItems = queryitems
        print("Your URL : \(urlbasic.url!)")
        URLSession.shared.dataTask(with: urlbasic.url!, completionHandler:{
            (data, response, error) in
            if(error != nil){
                print("error not nil:\(error!)")
            }else{
                do{
                    //https://developers.google.com/maps/documentation/directions/start
                    if let json : [String:Any] = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]{
                        print("Your Json Responed: \(json)")
                        if  (json["status"] as! String) == "OK"{
                            let routes = json["routes"] as? [Any]
                            let overview_polyline = routes?[0] as?[String:Any]
                            let polyString = overview_polyline?["points"] as?String
                            self.showPath(polyStr: polyString!)
                        }else{
                            //May be it is multi-thread. I am not sure if memory cycle exists.
                            DispatchQueue.main.async {
                                self.tapAddressName.text = "錯誤：" + (json["status"] as! String)
                            }
                            print("JSON Status not OK")
                        }
                    }
                }catch let error as NSError{
                    print("error:\(error)")
                }
            }
            
        }).resume()
    }
    func showPath(polyStr :String){
        let path = GMSPath(fromEncodedPath: polyStr)
        let polyline = GMSPolyline(path: path)
        polyline.strokeWidth = 3.0
        polyline.map = gpView
    }
    @IBAction func AddtotableView(_ sender: UIButton) {
        if let foo = clickPosition{
            let marker = GMSMarker()
            marker.position = foo.0
            marker.title = "第\(storedPositions.count)個"
            marker.snippet = foo.1
            marker.map = gpView
            storedPositions.append((foo.0,foo.1,marker))
            clickPosition = nil
            tableview.reloadData()
        }
    }
    
    func ShowAlert(title: String, message: String){
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "我知道了", style: .default, handler: { (action: UIAlertAction!) in
            //print("Handle Ok logic here")
        }))
        /*
        ac.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action: UIAlertAction!) in
            //print("Handle Ok logic here")
        }))
        */
        self.present(ac, animated: true, completion:{
            ac.view.superview?.isUserInteractionEnabled = true
            ac.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.alertControllerBackgroundTapped)))
        })
    }
    @objc func alertControllerBackgroundTapped()
    {
        self.dismiss(animated: true, completion: nil)
    }


}

