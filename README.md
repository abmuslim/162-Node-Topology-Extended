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
| **net_2** | 10.0.2.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_3** | 10.0.3.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_4** | 10.0.4.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_5** | 10.0.5.0/24 | 10.0.5.1 | switch5 | 16-26 | Edge_server8 | 
| **net_6** | 10.0.6.0/24 | 10.0.6.1 | switch6 | 28-35 | Edge_server9 | 
| **net_7** | 10.0.7.0/24 | 10.0.7.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_8** | 10.0.8.0/24 | 10.0.8.1 | switch2 | 7-15 | Edge_server4 |
| **net_9** | 10.0.9.0/24 | 10.0.9.1 | switch3 | 36-43 | Edge_server5 |
| **net_10** | 10.0.10.0/24 | 10.0.10.1 | switch4 | 44-51 | Edge_server6 | 
| **net_11** | 10.0.11.0/24 | 10.0.11.1 | switch5 | 16-26 | Edge_server8 | 
| **net_12** | 10.0.12.0/24 | 10.0.12.1 | switch6 | 28-35 | Edge_server9 | 
| **net_13** | 10.0.13.0/24 | 10.0.13.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_14** | 10.0.14.0/24 | 10.0.14.1 | switch2 | 7-15 | Edge_server4 |
| **net_15** | 10.0.15.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_16** | 10.0.16.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_17** | 10.0.17.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_18** | 10.0.18.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_19** | 10.0.19.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_20** | 10.0.20.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_21** | 10.0.21.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_22** | 10.0.22.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_23** | 10.0.23.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_24** | 10.0.24.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_25** | 10.0.25.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_26** | 10.0.26.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_27** | 10.0.27.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_28** | 10.0.28.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_29** | 10.0.29.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_30** | 10.0.30.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_31** | 10.0.31.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_32** | 10.0.32.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_33** | 10.0.33.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_34** | 10.0.34.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_35** | 10.0.35.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_36** | 10.0.36.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_37** | 10.0.37.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_38** | 10.0.38.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_39** | 10.0.39.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_40** | 10.0.40.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_41** | 10.0.41.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_42** | 10.0.42.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_43** | 10.0.43.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_44** | 10.0.44.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_45** | 10.0.45.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_46** | 10.0.46.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_47** | 10.0.47.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_48** | 10.0.48.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_49** | 10.0.49.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_50** | 10.0.50.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_51** | 10.0.51.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_52** | 10.0.52.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_53** | 10.0.53.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_54** | 10.0.54.0/24  | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_55** | 10.0.55.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_56** | 10.0.56.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_57** | 10.0.57.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_58** | 10.0.58.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_59** | 10.0.59.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_60** | 10.0.60.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_61** | 10.0.61.0/24 | 10.0.1.1 | R1 | S1-S4 | Serf1-Serf14 | 
| **net_62** | 10.0.62.0/24 | 10.0.2.1 | switch2 | 7-15 | Edge_server4 |
| **net_63** | 10.0.63.0/24 | 10.0.3.1 | switch3 | 36-43 | Edge_server5 |
| **net_64** | 10.0.64.0/24 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | 
| **net_65** | 10.0.65.0/24 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | 
| **net_66** | 10.0.66.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_67** | 10.0.67.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_68** | 10.0.68.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_69** | 10.0.69.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_70** | 10.0.70.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_71** | 10.0.71.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_72** | 10.0.72.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_73** | 10.0.73.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_74** | 10.0.74.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_75** | 10.0.75.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_76** | 10.0.76.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_77** | 10.0.77.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_78** | 10.0.78.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_79** | 10.0.79.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_80** | 10.0.80.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_81** | 10.0.81.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_82** | 10.0.82.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 
| **net_83** | 10.0.83.0/24 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | 



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





