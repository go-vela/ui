{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Update exposing (..)

import Api
import Browser.Dom as Dom
import Browser.Navigation as Navigation
import Focus exposing (resourceFocusFragment)
import List.Extra
import Pages.Build.Logs exposing (focusService, focusStep)
import Pages.Build.Model
    exposing
        ( GetLogs
        , PartialModel
        )
import RemoteData exposing (RemoteData(..), WebData)
import Task
import Util exposing (overwriteById)
import Vela
    exposing
        ( BuildNumber
        , Org
        , Repo
        , Service
        , ServiceNumber
        , Services
        , StepNumber
        , Steps
        )



-- UPDATE HELPERS


{-| clickStep : takes steps and step number, toggles step view state, and returns whether or not to fetch logs
-}
clickStep : WebData Steps -> StepNumber -> ( WebData Steps, Bool )
clickStep steps stepNumber =
    let
        ( stepsOut, action ) =
            RemoteData.unwrap ( steps, False )
                (\steps_ ->
                    ( toggleStepView stepNumber steps_ |> RemoteData.succeed
                    , True
                    )
                )
                steps
    in
    ( stepsOut
    , action
    )


{-| mergeSteps : takes takes current steps and incoming step information and merges them, updating old logs and retaining previous state.
-}
mergeSteps : Maybe String -> Bool -> WebData Steps -> Steps -> Steps
mergeSteps logFocus refresh currentSteps incomingSteps =
    let
        updatedSteps =
            currentSteps
                |> RemoteData.unwrap incomingSteps
                    (\steps ->
                        incomingSteps
                            |> List.map
                                (\incomingStep ->
                                    let
                                        ( viewing, focus ) =
                                            getStepInfo steps incomingStep.number

                                        s =
                                            { incomingStep
                                                | viewing = viewing
                                                , logFocus = focus
                                            }

                                        outStep =
                                            overwriteById
                                                s
                                                steps
                                    in
                                    Just <| Maybe.withDefault s outStep
                                )
                            |> List.filterMap identity
                    )
    in
    -- when not an automatic refresh, respect the url focus
    if not refresh then
        focusStep logFocus updatedSteps

    else
        updatedSteps


{-| isViewingStep : takes steps and step number and returns the step viewing state
-}
isViewingStep : WebData Steps -> StepNumber -> Bool
isViewingStep steps stepNumber =
    steps
        |> RemoteData.withDefault []
        |> List.filter (\step -> String.fromInt step.number == stepNumber)
        |> List.map .viewing
        |> List.head
        |> Maybe.withDefault False


{-| toggleStepView : takes steps and step number and toggles that steps viewing state
-}
toggleStepView : String -> Steps -> Steps
toggleStepView stepNumber =
    List.Extra.updateIf
        (\step -> String.fromInt step.number == stepNumber)
        (\step -> { step | viewing = not step.viewing })


{-| setAllStepViews : takes steps and value and sets all steps viewing state
-}
setAllStepViews : Bool -> Steps -> Steps
setAllStepViews value =
    List.map (\step -> { step | viewing = value })


{-| expandActiveStep : takes steps and sets step viewing state if the step is active
-}
expandActiveStep : StepNumber -> Steps -> Steps
expandActiveStep stepNumber steps =
    List.Extra.updateIf
        (\step -> (String.fromInt step.number == stepNumber) && (step.status /= Vela.Pending))
        (\step -> { step | viewing = True })
        steps


{-| getStepInfo : takes steps and step number and returns the step update information
-}
getStepInfo : Steps -> Int -> ( Bool, ( Maybe Int, Maybe Int ) )
getStepInfo steps stepNumber =
    steps
        |> List.filter (\step -> step.number == stepNumber)
        |> List.map (\step -> ( step.viewing, step.logFocus ))
        |> List.head
        |> Maybe.withDefault ( False, ( Nothing, Nothing ) )


{-| mergeServices : takes takes current steps and incoming step information and merges them, updating old logs and retaining previous state.
-}
mergeServices : Maybe String -> Bool -> WebData Services -> Services -> Services
mergeServices logFocus refresh currentServices incomingServices =
    let
        updatedServices =
            currentServices
                |> RemoteData.unwrap incomingServices
                    (\services ->
                        incomingServices
                            |> List.map
                                (\incomingService ->
                                    let
                                        ( viewing, focus ) =
                                            getServiceInfo services incomingService.number

                                        s =
                                            { incomingService
                                                | viewing = viewing
                                                , logFocus = focus
                                            }

                                        outService =
                                            overwriteById
                                                s
                                                services
                                    in
                                    Just <| Maybe.withDefault s outService
                                )
                            |> List.filterMap identity
                    )
    in
    -- when not an automatic refresh, respect the url focus
    if not refresh then
        focusService logFocus updatedServices

    else
        updatedServices


{-| clickService : takes steps and step number, toggles step view state, and returns whether or not to fetch logs
-}
clickService : WebData Services -> ServiceNumber -> ( WebData Services, Bool )
clickService services serviceNumber =
    let
        ( servicesOut, action ) =
            RemoteData.unwrap ( services, False )
                (\services_ ->
                    ( toggleServiceView serviceNumber services_ |> RemoteData.succeed
                    , True
                    )
                )
                services
    in
    ( servicesOut
    , action
    )


{-| isViewingService: takes steps and step number and returns the step viewing state
-}
isViewingService : WebData Services -> ServiceNumber -> Bool
isViewingService services serviceNumber =
    services
        |> RemoteData.withDefault []
        |> List.filter (\service -> String.fromInt service.number == serviceNumber)
        |> List.map .viewing
        |> List.head
        |> Maybe.withDefault False


{-| getServiceInfo : takes steps and step number and returns the step update information
-}
getServiceInfo : Services -> Int -> ( Bool, ( Maybe Int, Maybe Int ) )
getServiceInfo services serviceNumber =
    services
        |> List.filter (\service -> service.number == serviceNumber)
        |> List.map (\service -> ( service.viewing, service.logFocus ))
        |> List.head
        |> Maybe.withDefault ( False, ( Nothing, Nothing ) )


{-| toggleServiceView : takes services and step number and toggles that steps viewing state
-}
toggleServiceView : String -> Services -> Services
toggleServiceView serviceNumber =
    List.Extra.updateIf
        (\service -> String.fromInt service.number == serviceNumber)
        (\service -> { service | viewing = not service.viewing })


{-| setAllServiceViews : takes services and value and sets all services viewing state
-}
setAllServiceViews : Bool -> Services -> Services
setAllServiceViews value =
    List.map (\service -> { service | viewing = value })


{-| expandActiveService : takes steps and sets step viewing state if the step is active
-}
expandActiveService : ServiceNumber -> Services -> Services
expandActiveService serviceNumber services =
    List.Extra.updateIf
        (\service -> (String.fromInt service.number == serviceNumber) && (service.status /= Vela.Pending))
        (\service -> { service | viewing = True })
        services
