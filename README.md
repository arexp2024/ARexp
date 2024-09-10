# Experience: Practical Challenges for Indoor AR Applications
This project shows evaluation systems and datasets in our paper accepted for publication at ACM MobiCom 2024. 

## Our Findings
This paper shares the challenges facing today's augmented reality (AR) smartphone applications, particularly in the realm of localization and tracking failure. 
Our research identifies limitations in current vision-based landmarks such as QR codes and AprilTags, commonly used to aid in localization, and the drawbacks of LiDAR integration in variable lighting conditions, compromising AR's accuracy and functionality. 
Additionally, this paper examines the constraints of Inertial Measurement Units (IMU) on movement speed, highlighting its impact on the dynamic performance of AR applications. 
Based on our extensive 312 experimental cases for 109 hours, this paper presents the field with a nuanced analysis of the failure modes inherent in smartphone-based AR localization. 
We further explore a prototype solution which fuses ultra-wideband (UWB)-based sensing with the vision-based systems to alleviate these failure modes. 
Our approach addresses the immediate challenges of AR localization and opens avenues for future research and development in creating more spatially aware and interactive digital worlds. 

If you get interested in our study in detail, please check our paper at this link (anonymous). 

## Demonstration video
We are publishing our demonstration video at this link (anonymous). 
The playlist above includes our 15-subject case study in Sec. 2 to highlight the challenges of current AR systems. 

## Directories
```
.
├── README.md (me)
├── android
├── firmware
├── ios
├── src
├── truth
└── dataset.zip
```
+ android: Android apps to localize and track the smartphone
+ firmware: Binaries and C++ code to setup the specific hardware: DW3000 for UWB communication and the xy-stage
+ ios: iOS apps to localize and track the smartphone
+ src: Python codes to analyze the localization and tracking data
+ truth: Python codes to acquire the ground truth of localization and tracking
+ dataset.zip: recorded localization and tracking data through our experiments
+ Each directory includes README.md so that please also refer to each file

## Citation
If you use the dataset or evaluation system in your work, please consider citing the following paper:
```
@INPROCEEDINGS{anonymous,
  title     = "Experience: Practical Challenges for Indoor AR Applications",
  author    = "Anonymous",
  Booktitle = "ACM MobiCom '24: 30th Annual International Conference on Mobile Computing and Networking",
  pages   = "1--15",
  year    =  2024
}
```

## Article Author
Anonymous
