globals
[
  k
  t
  a1
  a2
  a3
  c1
  c2
]

breed [rebels rebel]
breed [cops cop]

turtles-own
[
  movement-patch
  active-in-vision
]

rebels-own
[
  jailed?
  active?
  hardship
  grievance
  risk-aversion
  arrest-probability
  cops-in-vision
  net-risk
  jail-time
  team
]

cops-own
[
  target
]

patches-own
[
  movement-value
  area-value
  time-since-capture
  total-value
  distance-from-nearest-cop
]

to setup
  clear-all
  set k 2.3
  set t 0.1
  set a1 0.2
  set a2 0.1
  set a3 0.7
  set c1 0.6
  set c2 0.4
  random-seed 4343
  setup-turtles
  setup-patches
  reset-ticks
end

to setup-turtles
  set-default-shape turtles "circle"
  create-rebels initial-population-density * count patches
  [
    move-to one-of patches with [not any? turtles-here]
    set color blue
    set size 0.9
    set team 0
    set jailed? false
    set active? false
    set hardship random-float 1
    set risk-aversion random-float 1
  ]
  create-cops initial-cop-density * count patches
  [
    move-to one-of patches with [not any? turtles-here]
    set color black
    set size 0.9
  ]
  ask n-of 50 rebels [
    set team 1
    set color 103
    set shape "team-one"
  ]
  ask n-of 50 rebels [
    set team 2
    set color 103
    set shape "team-two"
  ]
  ask n-of 50 rebels [
    set team 3
    set color 103
    set shape "team-three"
  ]
  ask n-of 50 rebels [
    set color 103
    set shape "team-four"

  ]
end

to setup-patches
  ask patches [
    set pcolor 39
    set movement-value 0
    set area-value 0
  ]
  ask n-of 6 patches [  ;; Retail shop
    ask patches in-radius 1.5 [
      set pcolor 58
      set area-value 4
    ]
  ]
  ask n-of 3 patches with [ area-value = 0 ] [  ;; Government building
    ask patches in-radius 1.5 [
      set pcolor 53
      set area-value 10
    ]
  ]
  ask n-of 2 patches with [ area-value = 0 ] [  ;; Police station
    ask patches in-radius 1.5 [
      set pcolor 44
      set area-value -10
    ]
  ]
  ask n-of 2 patches with [ area-value = 0 ] [  ;; Park
    ask patches in-radius 2.9 [
      set pcolor 55
      set area-value 6
    ]
  ]
end

to go
  agent-rule
  cop-rule
  patch-rule
  tick
end

to agent-rule  ;; The agent rule and everything necesarry to use it
  ask rebels
  [
     ifelse jail-time = 0
    [
      set jailed? false
      if movement?
      [
        rebel-movement-rule
      ]

      set grievance hardship * (1 - legitimacy)                                                         ;; G = H(1-L)
      set cops-in-vision count cops-on patches in-radius agent-vision                                   ;; C
      set active-in-vision 1 + count (rebels-on patches in-radius agent-vision) with [ active? = true and jailed? = false]     ;; A
      set arrest-probability 1 - exp ( - k * floor (cops-in-vision / active-in-vision))                       ;; P = 1 - exp[-k(C/A)]
      set net-risk risk-aversion * arrest-probability                                                   ;; N = RP
      ifelse grievance - net-risk > t [ become-active ] [ become-quiet ]                                ;; If G - N > T

    ]
    [
      set jail-time jail-time - 1
    ]
   ]
end

to become-active  ;; Change a rebel to active
  ifelse team != 0 [ set color 13 ] [ set color red ]
  set active? true
end

to become-quiet ;; Change a rebel to quiet
  ifelse team != 0 [ set color 103 ] [ set color blue ]
  set active? false
end

to cop-rule ;; The cop rule
  ask cops [
    if movement?
      [
        cop-movement-rule
      ]

    set target one-of (rebels-on patches in-radius cop-vision) with [ active? = true and jailed? = false ]
    ifelse target != nobody
    [ set movement-patch target arrest-target ]
    [ set movement-patch one-of patches in-radius cop-vision with [not any? cops-here and not any? rebels-here with [ jailed? = false ]]]
    if movement?
    [
      if movement-patch != nobody [ move-to movement-patch ]
    ]
  ]
end

to arrest-target
  ask target [
    set jailed? true
    set active? false
    set color gray
    ifelse maximum-jail-time = "Infinity"
    [set jail-time random 2147483647]                ;; As close to infinity as we can get
    [set jail-time random maximum-jail-time-years]
    ask patches in-radius 1.5 [ set time-since-capture time-since-capture + 3 ]
   ]
end

to patch-rule
  ask patches [
    set distance-from-nearest-cop distance min-one-of cops [ distance myself ]
    ifelse heatmap? [ set pcolor scale-color orange distance-from-nearest-cop -10 10 ] [ set pcolor 39 ]
  ]
  ask patches with [ time-since-capture > 0 ] [
    set time-since-capture time-since-capture - 1
  ]

end

to rebel-movement-rule
  ;; a1 * area-value - a2(distance-2*friend) - a3(e^(arrest_probability)  + jail term)
  ask patches in-radius agent-vision [
    let current-team [ team ] of myself
    let cops-in-new-vision count cops-on patches in-radius agent-vision
    let active-in-new-vision count rebels-on patches in-radius agent-vision
    let new-arrest-probability 1 - exp ( - k * floor (cops-in-new-vision / active-in-new-vision))
    let friends-in-new-vision 0
    ( ifelse current-team = 0 [ set friends-in-new-vision 0 ]
             current-team = 1 [ set friends-in-new-vision count rebels in-radius 2 with [ team = 1 and jailed? = false ] ]
             current-team = 2 [ set friends-in-new-vision count rebels in-radius 2 with [ team = 2 and jailed? = false ] ]
             current-team = 3 [ set friends-in-new-vision count rebels in-radius 2 with [ team = 3 and jailed? = false ] ]
             current-team = 4 [ set friends-in-new-vision count rebels in-radius 2 with [ team = 4 and jailed? = false ] ]
    )
    let distance-to-patch distance myself
    set total-value a1 * area-value - a2 * ( distance-to-patch - 2 * friends-in-new-vision ) - a3 * ( exp ( new-arrest-probability ) + time-since-capture )
  ]
  let current-distance-from-cop [ distance-from-nearest-cop ] of patch-here
  set movement-patch max-one-of patches in-radius agent-vision with [not any? cops-here and not any? rebels-here with [ jailed? = false ] and distance-from-nearest-cop >= current-distance-from-cop ] [ total-value ]
  if movement-patch != nobody [move-to movement-patch]
end

to cop-movement-rule
  ask patches in-radius cop-vision [
    let cops-in-new-vision count cops-on patches in-radius agent-vision
    let active-in-new-vision count rebels-on patches in-radius agent-vision
    let agent-density active-in-new-vision / cops-in-new-vision
    let distance-to-patch distance myself
    set total-value c1 * agent-density - c2 * distance-to-patch
  ]
  set movement-patch max-one-of patches in-radius cop-vision with [not any? cops-here and not any? rebels-here with [ jailed? = false ] ] [ total-value ]
  if movement-patch != nobody [move-to movement-patch]
end
@#$#@#$#@
GRAPHICS-WINDOW
487
10
901
425
-1
-1
10.15
1
10
1
1
1
0
1
1
1
0
39
0
39
1
1
1
ticks
30.0

BUTTON
8
10
71
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
9
56
212
89
initial-population-density
initial-population-density
0
1
0.7
0.01
1
NIL
HORIZONTAL

SLIDER
10
97
210
130
initial-cop-density
initial-cop-density
0
1
0.04
0.001
1
NIL
HORIZONTAL

SLIDER
11
147
210
180
legitimacy
legitimacy
0
1
0.8
0.01
1
NIL
HORIZONTAL

SLIDER
13
228
213
261
cop-vision
cop-vision
0
10
5.0
0.1
1
NIL
HORIZONTAL

SLIDER
13
187
213
220
agent-vision
agent-vision
0
10
5.0
0.1
1
NIL
HORIZONTAL

SLIDER
15
327
233
360
maximum-jail-time-years
maximum-jail-time-years
0
100
10.0
1
1
years
HORIZONTAL

CHOOSER
14
271
219
316
maximum-jail-time
maximum-jail-time
"Amount of years (see slider)" "Infinity"
0

BUTTON
85
11
148
44
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
10
376
462
643
Active Rebels
Time
Amount
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Active" 1.0 0 -2674135 true "" "plot count rebels with [ active? = true ]"
"Quiet" 1.0 0 -13345367 true "" "plot count rebels with [ active? = false ]"
"Jailed" 1.0 0 -7500403 true "" "plot count rebels with [ jailed? = true ]"

SWITCH
238
50
357
83
movement?
movement?
0
1
-1000

PLOT
490
436
898
670
Active Rebels 2
Time
Amount
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot count rebels with [ active? = true ]"

SWITCH
257
118
367
151
heatmap?
heatmap?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

team-four
false
10
Circle -13345367 true true 0 0 300
Polygon -13840069 true false 135 90 75 120 120 45 195 60 210 255 150 255 150 90 135 90
Polygon -13840069 true false 150 75 150 120 75 120
Rectangle -13345367 true true 60 30 240 255
Polygon -13840069 true false 120 105 75 105 90 45 195 45 210 135 135 210 225 225 225 270 75 255 165 120 135 90 120 105
Rectangle -13345367 true true 75 45 225 270
Polygon -13840069 true false 105 60 210 60 150 150 210 165 240 225 180 270 120 240 120 210 180 240 210 210 150 180 120 165 165 90 90 90 90 60 105 60
Rectangle -13345367 true true 90 60 240 270
Polygon -13840069 true false 90 60 90 180 165 180 180 270 210 270 210 75 165 75 165 135 120 135 120 75 90 75

team-one
false
10
Circle -13345367 true true 0 0 300
Polygon -13840069 true false 135 90 75 120 120 45 195 60 210 255 150 255 150 90 135 90
Polygon -13840069 true false 150 75 150 120 75 120

team-three
false
10
Circle -13345367 true true 0 0 300
Polygon -13840069 true false 135 90 75 120 120 45 195 60 210 255 150 255 150 90 135 90
Polygon -13840069 true false 150 75 150 120 75 120
Rectangle -13345367 true true 60 30 240 255
Polygon -13840069 true false 120 105 75 105 90 45 195 45 210 135 135 210 225 225 225 270 75 255 165 120 135 90 120 105
Rectangle -13345367 true true 75 45 225 270
Polygon -13840069 true false 105 60 210 60 150 150 210 165 240 225 180 270 120 240 120 210 180 240 210 210 150 180 120 165 165 90 90 90 90 60 105 60

team-two
false
10
Circle -13345367 true true 0 0 300
Polygon -13840069 true false 135 90 75 120 120 45 195 60 210 255 150 255 150 90 135 90
Polygon -13840069 true false 150 75 150 120 75 120
Rectangle -13345367 true true 75 45 210 255
Polygon -13840069 true false 90 75 135 45 210 60 225 105 135 195 120 225 225 225 225 270 90 255 90 225 105 180 180 105 165 75 135 75 105 105 75 90

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
