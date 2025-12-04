# Containerlab Topology with 162 Nodes
This code repository consists a complete Containerlab topology with Routers, Switches and end nodes.

# Overview
- The network consists of 37 switches, 27 routers and 162 end nodes.
- Consists of 83 subnetworks
- Routers are configured with OSPF (Area 0)

# Architecture
This section describes the design of the network.

### Network Topology
The nodes declared as switches, routers and end nodes are marked in green, yellow and white respectively.<br/>

<img width="1853" height="1077" alt="fig_network_topo_final" src="https://github.com/user-attachments/assets/143e907e-93f6-4e75-90ec-c8e6de468fa0" />

### Network Segments
| Segment | Subnet | Gateway | Router | Switch | Nodes |                                          
|---------|--------|---------|---------|---------|-------------|
| **net_1** | 10.0.1.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_2** | 10.0.2.0/24 | 10.0.2.1 | R1 | S5 | Serf15 |
| **net_3** | 10.0.3.0/24 | 10.0.3.1 | R1 | - | Serf16 |
| **net_4** | 10.0.4.0/24 | 10.0.4.1 |  | 44-51 | Serf17 | 
| **net_5** | 10.0.5.0/24 | 10.0.5.1 | switch5 | 16-26 | Serf18 | 
| **net_6** | 10.0.6.0/24 | 10.0.6.1 | switch6 | 28-35 | Serf19 | 
| **net_7** | 10.0.7.0/24 | 10.0.7.1 | R1 | S1-S4 | Serf20, Serf21 | 
| **net_8** | 10.0.8.0/24 | 10.0.8.1 | switch2 | 7-15 | Serf22-Serf25 |
| **net_9** | 10.0.9.0/24 | 10.0.9.1 | switch3 | 36-43 | serf26 |
| **net_10** | 10.0.10.0/24 | 10.0.10.1 | switch4 | 44-51 | serf27-serf29 | 
| **net_11** | 10.0.11.0/24 | 10.0.11.1 | switch5 | 16-26 | serf30 | 
| **net_12** | 10.0.12.0/24 | 10.0.12.1 | switch6 | 28-35 | serf31 | 
| **net_13** | 10.0.13.0/24 | 10.0.13.1 | R1 | S1-S4 | serf32 | 
| **net_14** | 10.0.14.0/24 | 10.0.14.1 | switch2 | 7-15 | serf33, serf34 |
| **net_15** | 10.0.15.0/24 | 10.0.15.1 | switch3 | 36-43 | serf35-serf42 |
| **net_16** | 10.0.16.0/24 | 10.0.16.1 | switch4 | 44-51 | serf43-serf45 | 
| **net_17** | 10.0.17.0/24 | 10.0.17.1 | switch5 | 16-26 | serf46 | 
| **net_18** | 10.0.18.0/24 | 10.0.18.1 | switch6 | 28-35 | serf47 | 
| **net_19** | 10.0.19.0/24 | 10.0.19.1 | R1 | S1-S4 | serf48 | 
| **net_20** | 10.0.20.0/24 | 10.0.20.1 | switch2 | 7-15 | serf49 |
| **net_21** | 10.0.21.0/24 | 10.0.21.1 | switch3 | 36-43 | serf50 |
| **net_22** | 10.0.22.0/24 | 10.0.22.1 | switch4 | 44-51 | serf51 | 
| **net_23** | 10.0.23.0/24 | 10.0.23.1 | switch5 | 16-26 | serf52 | 
| **net_24** | 10.0.24.0/24 | 10.0.24.1 | switch6 | 28-35 | serf53 | 
| **net_25** | 10.0.25.0/24 | 10.0.25.1 | R1 | S1-S4 | serf54 | 
| **net_26** | 10.0.26.0/24 | 10.0.26.1 | switch2 | 7-15 | serf55 |
| **net_27** | 10.0.27.0/24 | 10.0.27.1 | switch3 | 36-43 | serf56 |
| **net_28** | 10.0.28.0/24 | 10.0.28.1 | switch4 | 44-51 | serf57 | 
| **net_29** | 10.0.29.0/24 | 10.0.29.1 | switch5 | 16-26 | serf58 | 
| **net_30** | 10.0.30.0/24 | 10.0.30.1 | switch6 | 28-35 | serf59 | 
| **net_31** | 10.0.31.0/24 | 10.0.31.1 | R1 | S1-S4 | serf60 | 
| **net_32** | 10.0.32.0/24 | 10.0.32.1 | switch2 | 7-15 | serf61 |
| **net_33** | 10.0.33.0/24 | 10.0.33.1 | switch3 | 36-43 | serf62 |
| **net_34** | 10.0.34.0/24 | 10.0.34.1 | switch4 | 44-51 | serf63 | 
| **net_35** | 10.0.35.0/24 | 10.0.35.1 | switch5 | 16-26 | serf64 | 
| **net_36** | 10.0.36.0/24 | 10.0.36.1 | switch6 | 28-35 | serf65 | 
| **net_37** | 10.0.37.0/24 | 10.0.37.1 | R1 | S1-S4 | serf66-serf68 | 
| **net_38** | 10.0.38.0/24 | 10.0.38.1 | switch2 | 7-15 | serf69-serf79 |
| **net_39** | 10.0.39.0/24 | 10.0.39.1 | switch3 | 36-43 | serf80 |
| **net_40** | 10.0.40.0/24 | 10.0.40.1 | switch4 | 44-51 | serf81 | 
| **net_41** | 10.0.41.0/24 | 10.0.41.1 | switch5 | 16-26 | serf82 | 
| **net_42** | 10.0.42.0/24 | 10.0.42.1 | switch6 | 28-35 | serf83-serf89 | 
| **net_43** | 10.0.43.0/24 | 10.0.43.1 | R1 | S1-S4 | serf90 | 
| **net_44** | 10.0.44.0/24 | 10.0.44.1 | switch2 | 7-15 | serf91 |
| **net_45** | 10.0.45.0/24 | 10.0.45.1 | switch3 | 36-43 | serf92 |
| **net_46** | 10.0.46.0/24 | 10.0.46.1 | switch4 | 44-51 | serf93 | 
| **net_47** | 10.0.47.0/24 | 10.0.47.1 | switch5 | 16-26 | serf94 | 
| **net_48** | 10.0.48.0/24 | 10.0.48.1 | switch6 | 28-35 | serf95 | 
| **net_49** | 10.0.49.0/24 | 10.0.49.1 | R1 | S1-S4 | serf96-serf98 | 
| **net_50** | 10.0.50.0/24 | 10.0.50.1 | switch2 | 7-15 | serf99 |
| **net_51** | 10.0.51.0/24 | 10.0.51.1 | switch3 | 36-43 | serf100 |
| **net_52** | 10.0.52.0/24 | 10.0.52.1 | switch4 | 44-51 | serf101 | 
| **net_53** | 10.0.53.0/24 | 10.0.53.1 | switch5 | 16-26 | serf102 | 
| **net_54** | 10.0.54.0/24 | 10.0.54.1 | switch6 | 28-35 | serf103 | 
| **net_55** | 10.0.55.0/24 | 10.0.55.1 | R1 | S1-S4 | serf104 | 
| **net_56** | 10.0.56.0/24 | 10.0.56.1 | switch2 | 7-15 | serf105 |
| **net_57** | 10.0.57.0/24 | 10.0.57.1 | switch3 | 36-43 | serf106 |
| **net_58** | 10.0.58.0/24 | 10.0.58.1 | switch4 | 44-51 | serf107 | 
| **net_59** | 10.0.59.0/24 | 10.0.59.1 | switch5 | 16-26 | serf108 | 
| **net_60** | 10.0.60.0/24 | 10.0.60.1 | switch6 | 28-35 | serf109 | 
| **net_61** | 10.0.61.0/24 | 10.0.61.1 | R1 | S1-S4 | serf110 | 
| **net_62** | 10.0.62.0/24 | 10.0.62.1 | switch2 | 7-15 | serf111 |
| **net_63** | 10.0.63.0/24 | 10.0.63.1 | switch3 | 36-43 | serf112-serf114 |
| **net_64** | 10.0.64.0/24 | 10.0.64.1 | switch4 | 44-51 | serf115, serf116 | 
| **net_65** | 10.0.65.0/24 | 10.0.65.1 | switch5 | 16-26 | serf117-serf120 | 
| **net_66** | 10.0.66.0/24 | 10.0.66.1 | switch6 | 28-35 | serf121 | 
| **net_67** | 10.0.67.0/24 | 10.0.67.1 | switch6 | 28-35 | serf122 | 
| **net_68** | 10.0.68.0/24 | 10.0.68.1 | switch6 | 28-35 | serf123 | 
| **net_69** | 10.0.69.0/24 | 10.0.69.1 | switch6 | 28-35 | serf124 | 
| **net_70** | 10.0.70.0/24 | 10.0.70.1 | switch6 | 28-35 | serf125 | 
| **net_71** | 10.0.71.0/24 | 10.0.71.1 | switch6 | 28-35 | serf126 | 
| **net_72** | 10.0.72.0/24 | 10.0.72.1 | switch6 | 28-35 | serf127 | 
| **net_73** | 10.0.73.0/24 | 10.0.73.1 | switch6 | 28-35 | serf128 | 
| **net_74** | 10.0.74.0/24 | 10.0.74.1 | switch6 | 28-35 | serf129 | 
| **net_75** | 10.0.75.0/24 | 10.0.75.1 | switch6 | 28-35 | serf130-serf141 | 
| **net_76** | 10.0.76.0/24 | 10.0.76.1 | switch6 | 28-35 | serf142-serf146 | 
| **net_77** | 10.0.77.0/24 | 10.0.77.1 | switch6 | 28-35 | serf147-serf156 | 
| **net_78** | 10.0.78.0/24 | 10.0.78.1 | switch6 | 28-35 | serf157 | 
| **net_79** | 10.0.79.0/24 | 10.0.79.1 | switch6 | 28-35 | serf158 | 
| **net_80** | 10.0.80.0/24 | 10.0.80.1 | switch6 | 28-35 | serf159 | 
| **net_81** | 10.0.81.0/24 | 10.0.81.1 | switch6 | 28-35 | serf160 | 
| **net_82** | 10.0.82.0/24 | 10.0.82.1 | switch6 | 28-35 | serf161 | 
| **net_83** | 10.0.83.0/24 | 10.0.83.1 | switch6 | 28-35 | serf162 | 



<table>
<tr><th>Table 1 Heading 1 </th><th>Table 1 Heading 2</th></tr>
<tr><td>

|Table 1| Middle | Table 2|
|--|--|--|
|a| not b|and c |

</td><td>

|b|1|2|3| 
|--|--|--|--|
|a|s|d|f|

</td></tr> </table>





