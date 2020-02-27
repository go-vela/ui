{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Game.Game exposing
    ( Args
    , Bullet
    , Direction(..)
    , Enemy
    , bulletSize
    , fadeSteps
    , gameKeyDown
    , gameKeyUp
    , gameover
    , init
    , keyToDirection
    , loop
    , newBullet
    , newGame
    , update
    , view
    )

import Browser.Events
import Html
    exposing
        ( Html
        , div
        , text
        )
import Html.Attributes exposing (class)
import Http exposing (Error(..))
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import Svg
import Svg.Attributes
import Util
import Vela exposing (Build)



-- GAME


{-| Args msg : arguments parsed from the model required to play the game
-}
type alias Args msg =
    { play : Bool
    , frame : Int
    , build : WebData Build
    , key : ( String, Int )
    , startGame : msg
    , endGame : msg
    , score : Int
    , player : Player
    , bullets : List Bullet
    , enemies : List Enemy
    }


{-| Position : record to hold x & y coordinates for game objects
-}
type alias Position =
    { x : Int
    , y : Int
    }


{-| Direction : type enum for directions
-}
type Direction
    = Up
    | Down
    | Left
    | Right
    | None



-- PLAYER


{-| Player : record for holding player position and speed
-}
type alias Player =
    { position : Position
    , speed : Int
    , direction : Direction
    }


{-| initPlayer : initializes a new player
-}
initPlayer : Player
initPlayer =
    Player { x = 490, y = 330 } 8 None



-- BULLET


{-| Bullet : record for holding bullet position and speed
-}
type alias Bullet =
    { position : Position
    , speed : Int
    }


{-| newBullet : takes player position and returns a new bullet above the player
-}
newBullet : Position -> Bullet
newBullet playerPosition =
    Bullet { x = playerPosition.x + 16, y = playerPosition.y } 8


bulletSize : Int
bulletSize =
    10



-- ENEMY


{-| Enemy : record for holding enemy position and speed
-}
type alias Enemy =
    { position : Position
    , speed : Int
    }


{-| newEnemy : takes spawn position and speed and returns a new enemy
-}
newEnemy : Position -> Int -> Enemy
newEnemy position speed =
    Enemy { x = position.x, y = position.y } speed


enemyWidth : Int
enemyWidth =
    30


enemyHeight : Int
enemyHeight =
    3



-- SPAWN CONSTANTS


low : Int
low =
    70


medium : Int
medium =
    55


high : Int
high =
    40


slowest : Int
slowest =
    2


slower : Int
slower =
    3


slow : Int
slow =
    4


normal : Int
normal =
    5


fast : Int
fast =
    6


faster : Int
faster =
    7



-- GAME


init : msg -> msg -> Args msg
init startGame endGame =
    Args
        False
        0
        RemoteData.NotAsked
        ( "", 0 )
        startGame
        endGame
        0
        initPlayer
        []
        initEnemies


newGame : WebData Build -> msg -> msg -> Args msg
newGame build startGame endGame =
    Args
        True
        0
        build
        ( "", 0 )
        startGame
        endGame
        0
        initPlayer
        []
        initEnemies


gameover : Args msg -> Args msg
gameover game =
    { game | play = False }


initEnemies : List Enemy
initEnemies =
    [ newEnemy { x = -300, y = high } slowest
    , newEnemy { x = -300, y = medium } slow
    , newEnemy { x = -300, y = low } normal
    , newEnemy { x = -1000, y = low } normal
    , newEnemy { x = -1250, y = medium } fast
    , newEnemy { x = -1250, y = high } slow
    , newEnemy { x = -1250, y = low } slower
    , newEnemy { x = -1500, y = low } normal
    , newEnemy { x = -1750, y = high } slower
    , newEnemy { x = -1750, y = medium } slow
    , newEnemy { x = -1750, y = low } normal
    , newEnemy { x = -2000, y = low } faster
    , newEnemy { x = -2000, y = low } normal
    , newEnemy { x = -2000, y = medium } slower
    , newEnemy { x = -2000, y = high } slow
    , newEnemy { x = -2000, y = medium } fast
    ]


{-| loop : takes model and determines if the site should run the game loop
-}
loop : Args msg -> (Float -> msg) -> Sub msg
loop game onAnimationFrame =
    Sub.batch <|
        if game.play then
            [ Browser.Events.onAnimationFrameDelta onAnimationFrame ]

        else
            []



-- VIEW


view : Args msg -> Html msg
view { play, build, player, bullets, enemies, score } =
    div
        [ class "game-container"
        , if play then
            class "game-fade-in"

          else
            class "game-fade-out"
        ]
        [ Svg.svg
            [ Svg.Attributes.width "1000"
            , Svg.Attributes.height "400"
            , Svg.Attributes.viewBox "0 0 1000 400"
            , Svg.Attributes.style "background: var(--color-bg)"
            ]
          <|
            [ Svg.text_
                [ Svg.Attributes.textAnchor "start"
                , Svg.Attributes.fill "var(--color-green)"
                , Svg.Attributes.x "10"
                , Svg.Attributes.y "20"
                , Svg.Attributes.fontFamily "monospace"
                , Svg.Attributes.fontWeight "300"
                , Svg.Attributes.fontSize "16"
                ]
                [ text <| "Constellation Cleanup" ]
            , Svg.text_
                [ Svg.Attributes.textAnchor "start"
                , Svg.Attributes.fill "var(--color-primary)"
                , Svg.Attributes.x "30"
                , Svg.Attributes.y "40"
                , Svg.Attributes.fontFamily "monospace"
                , Svg.Attributes.fontWeight "300"
                , Svg.Attributes.fontSize "14"
                ]
                [ text <| "score: " ++ String.fromInt score ]
            , Svg.text_
                [ Svg.Attributes.textAnchor "start"
                , Svg.Attributes.fill "var(--color-primary)"
                , Svg.Attributes.x "10"
                , Svg.Attributes.y "96%"
                , Svg.Attributes.fontFamily "monospace"
                , Svg.Attributes.fontWeight "300"
                , Svg.Attributes.fontSize "14"
                ]
                [ text "use left/right arrows and spacebar to play (esc to quit)" ]
            , gameOver build
            , viewPlayer player.position
            ]
                ++ viewBullets bullets
                ++ viewEnemies enemies
        ]


gameOver : WebData Build -> Html msg
gameOver build =
    case build of
        RemoteData.Success b ->
            if Vela.isComplete b.status then
                Svg.g []
                    [ Svg.text_
                        [ Svg.Attributes.textAnchor "left"
                        , Svg.Attributes.fill "var(--color-primary)"
                        , Svg.Attributes.x "375"
                        , Svg.Attributes.y "50%"
                        , Svg.Attributes.fontFamily "monospace"
                        , Svg.Attributes.fontWeight "300"
                        , Svg.Attributes.fontSize "18"
                        ]
                        [ text "your build is" ]
                    , Svg.text_
                        [ Svg.Attributes.textAnchor "left"
                        , statusToFill b.status
                        , Svg.Attributes.x "525"
                        , Svg.Attributes.y "50%"
                        , Svg.Attributes.fontFamily "monospace"
                        , Svg.Attributes.fontWeight "300"
                        , Svg.Attributes.fontSize "18"
                        ]
                        [ text "finished!" ]
                    ]

            else
                text ""

        _ ->
            text ""


statusToFill : Vela.Status -> Svg.Attribute msg
statusToFill status =
    case status of
        Vela.Success ->
            Svg.Attributes.fill "var(--color-green)"

        _ ->
            Svg.Attributes.fill "var(--color-red)"


viewPlayer : Position -> Svg.Svg msg
viewPlayer position =
    Svg.svg
        [ Svg.Attributes.width <| String.fromInt 32
        , Svg.Attributes.height <| String.fromInt 32
        , Svg.Attributes.x <| String.fromInt position.x
        , Svg.Attributes.y <| String.fromInt position.y
        , Svg.Attributes.viewBox "0 0 1500 1500"
        , Svg.Attributes.class "vela-logo"
        , Svg.Attributes.class "starship"
        ]
        [ Svg.path [ Svg.Attributes.class "vela-logo-star", Svg.Attributes.d "M1477.22 329.54l-139.11-109.63 11.45-176.75-147.26 98.42-164.57-65.51 48.11 170.47-113.16 136.27 176.99 6.93 94.63 149.72 61.28-166.19 171.64-43.73z" ] []
        , Svg.path [ Svg.Attributes.class "vela-logo-outer", Svg.Attributes.d "M1174.75 635.12l-417.18 722.57a3.47 3.47 0 01-6 0L125.38 273.13a3.48 3.48 0 013-5.22h796.86l39.14-47.13-14.19-50.28h-821.8A100.9 100.9 0 0041 321.84L667.19 1406.4a100.88 100.88 0 00174.74 0l391.61-678.27z" ] []
        , Svg.path [ Svg.Attributes.class "vela-logo-inner", Svg.Attributes.d "M1087.64 497.29l-49.37-1.93-283.71 491.39L395.9 365.54H288.13l466.43 807.88 363.02-628.76-29.94-47.37z" ] []
        ]


viewBullets : List Bullet -> List (Svg.Svg msg)
viewBullets bullets =
    List.map viewBullet bullets


viewBullet : Bullet -> Svg.Svg msg
viewBullet bullet =
    Svg.circle
        [ Svg.Attributes.cx <| String.fromInt bullet.position.x
        , Svg.Attributes.cy <| String.fromInt bullet.position.y
        , Svg.Attributes.r "3"
        , Svg.Attributes.fill "var(--color-yellow)"
        ]
        []


viewEnemies : List Enemy -> List (Svg.Svg msg)
viewEnemies enemies =
    List.map viewEnemy enemies


viewEnemy : Enemy -> Svg.Svg msg
viewEnemy enemy =
    Svg.rect
        [ Svg.Attributes.x <| String.fromInt enemy.position.x
        , Svg.Attributes.y <| String.fromInt enemy.position.y
        , Svg.Attributes.width <| String.fromInt <| enemyWidth
        , Svg.Attributes.height <| String.fromInt <| enemyHeight
        , Svg.Attributes.fill "var(--color-yellow)"
        ]
        []



-- HELPERS


keyToDirection : String -> Direction
keyToDirection key =
    case key of
        "ArrowLeft" ->
            Left

        "ArrowRight" ->
            Right

        _ ->
            None


gameKeyDown : Args msg -> Page -> String -> msg -> msg -> ( Args msg, Cmd msg )
gameKeyDown game page key startGame endGame =
    let
        newKey =
            setKey key game.key

        player =
            game.player

        result =
            if game.play then
                if key == "Escape" then
                    ( { game | play = False, key = newKey }
                    , if game.play then
                        Util.dispatch endGame

                      else
                        Cmd.none
                    )

                else if key == " " then
                    ( { game | bullets = newBullet game.player.position :: game.bullets }
                    , Cmd.none
                    )

                else
                    case keyToDirection key of
                        Left ->
                            ( { game | player = { player | direction = Left } }, Cmd.none )

                        Right ->
                            ( { game | player = { player | direction = Right } }, Cmd.none )

                        _ ->
                            ( game, Cmd.none )

            else if key == "v" then
                let
                    onBuild =
                        case page of
                            Pages.Build _ _ _ _ ->
                                True

                            _ ->
                                False
                in
                ( { game | key = newKey }
                , if onBuild && Tuple.second newKey == 5 then
                    Util.dispatch startGame

                  else
                    Cmd.none
                )

            else
                ( { game | key = newKey }, Cmd.none )
    in
    result


setKey : String -> ( String, Int ) -> ( String, Int )
setKey key ( lastKey, currentCount ) =
    let
        newCount =
            if key == lastKey then
                currentCount + 1

            else
                1
    in
    ( key, newCount )


gameKeyUp : Args msg -> String -> ( Args msg, Cmd msg )
gameKeyUp game key =
    let
        player =
            game.player

        g =
            if game.play then
                case keyToDirection key of
                    Left ->
                        { game | player = { player | direction = None } }

                    Right ->
                        { game | player = { player | direction = None } }

                    _ ->
                        { game | player = { player | direction = player.direction } }

            else
                game
    in
    ( g, Cmd.none )


update : Args msg -> WebData Build -> Args msg
update game build =
    let
        player =
            game.player

        playerPosition =
            case game.player.direction of
                Left ->
                    { x = max 0 <| player.position.x - player.speed, y = player.position.y }

                Right ->
                    { x = min 970 <| player.position.x + player.speed, y = player.position.y }

                _ ->
                    player.position

        ( bullets, enemies ) =
            ( updateBullets game.bullets
            , updateEnemies game.enemies
            )

        ( remainingBullets, remainingEnemies ) =
            handleCollisions bullets enemies

        newScore =
            game.score + (List.length game.enemies - List.length remainingEnemies)

        updatedEnemies =
            addEnemy build game.frame <| remainingEnemies

        nextFrame =
            incrementFrame game.frame
    in
    { game
        | build = build
        , frame = nextFrame
        , player = { player | position = playerPosition }
        , bullets = remainingBullets
        , enemies = updatedEnemies
        , score = newScore
    }


addEnemy : WebData Build -> Int -> List Enemy -> List Enemy
addEnemy build frame enemies =
    case build of
        RemoteData.Success b ->
            if not <| Vela.isComplete b.status then
                case frame of
                    0 ->
                        newEnemy { x = -200, y = high } fast :: enemies

                    60 ->
                        [ newEnemy { x = -200, y = medium } slower, newEnemy { x = -200, y = low } normal ] ++ enemies

                    120 ->
                        newEnemy { x = -200, y = high } normal :: enemies

                    180 ->
                        [ newEnemy { x = -400, y = high } fast, newEnemy { x = -300, y = low } faster ] ++ enemies

                    _ ->
                        enemies

            else
                enemies

        _ ->
            enemies


incrementFrame : Int -> Int
incrementFrame frame =
    if frame + 1 > 240 then
        0

    else
        frame + 1


updateEnemies : List { b | position : { x : number, y : a }, speed : number } -> List { b | position : { x : number, y : a }, speed : number }
updateEnemies objects =
    List.map (\object -> { object | position = { x = object.position.x + object.speed, y = object.position.y } }) objects


updateBullets : List { b | position : { x : number, y : number }, speed : number } -> List { b | position : { x : number, y : number }, speed : number }
updateBullets objects =
    List.map (\object -> { object | position = { x = object.position.x, y = object.position.y - object.speed } }) objects


handleCollisions : List Bullet -> List Enemy -> ( List Bullet, List Enemy )
handleCollisions bullets enemies =
    let
        collisions : List ( Bullet, List (Maybe Enemy) )
        collisions =
            List.filter (\( _, enemies_ ) -> isNotListOfNothing enemies_) <|
                List.map
                    (\bullet -> ( bullet, List.map (\enemy -> isCollision bullet enemy) enemies ))
                    bullets

        bulletsToDestroy : List Bullet
        bulletsToDestroy =
            List.map (\( bullet, _ ) -> bullet) collisions

        enemiesToDestroy : List Enemy
        enemiesToDestroy =
            List.filterMap (\enemy -> enemy) <|
                List.concat <|
                    List.map (\( _, enemies_ ) -> enemies_) collisions

        remainingBullets =
            List.filter (\bullet -> not <| List.member bullet bulletsToDestroy) bullets

        remainingEnemies =
            List.filter (\enemy -> not <| List.member enemy enemiesToDestroy) enemies
    in
    ( remainingBullets, remainingEnemies )


isCollision : Bullet -> Enemy -> Maybe Enemy
isCollision bullet enemy =
    let
        bulletCollisionSize =
            bulletSize

        enemyWidthCollisionSize =
            enemyWidth // 3

        enemyHeightCollisionSize =
            enemyHeight
    in
    if
        (bullet.position.x
            + bulletCollisionSize
            > enemy.position.x
            - enemyWidthCollisionSize
            && bullet.position.x
            - bulletCollisionSize
            < enemy.position.x
            + enemyWidthCollisionSize
        )
            && (bullet.position.y
                    + bulletCollisionSize
                    > enemy.position.y
                    - enemyHeightCollisionSize
                    && bullet.position.y
                    - bulletCollisionSize
                    < enemy.position.y
               )
    then
        Just enemy

    else
        Nothing


isNotListOfNothing : List (Maybe a) -> Bool
isNotListOfNothing list =
    List.length
        (List.filter
            (\item ->
                case item of
                    Just _ ->
                        True

                    Nothing ->
                        False
            )
            list
        )
        > 0


fadeSteps : Bool -> Html.Attribute msg
fadeSteps play =
    if play then
        class "steps-fade-out"

    else
        class "steps-fade-in"
