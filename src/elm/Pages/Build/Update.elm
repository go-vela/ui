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
import Pages.Build.Logs exposing (focus)
import RemoteData exposing (RemoteData(..), WebData)
import Task
import Util exposing (overwriteById)
import Vela
    exposing
        ( BuildNumber
        , LogFocus
        , Org
        , Repo
        , Resources
        , Service
        , ServiceNumber
        , Services
        , StepNumber
        , Steps
        , updateBuild
        , updateBuildSteps
        , updateBuildStepsFollowing
        )



-- UPDATE


{-| clickResource : takes resources and resource number, toggles resource view state, and returns whether or not to fetch logs
-}
clickResource : WebData (Resources a) -> String -> ( WebData (Resources a), Bool )
clickResource resources stepNumber =
    resources
        |> RemoteData.unwrap ( resources, False )
            (\resources_ ->
                ( toggleView stepNumber resources_ |> RemoteData.succeed
                , True
                )
            )


{-| merge : takes takes current resources and incoming resource information and merges them, updating old logs and retaining previous state.
-}
merge : Maybe String -> Bool -> WebData (Resources a) -> Resources a -> Resources a
merge logFocus refresh current incoming =
    let
        merged =
            current
                |> RemoteData.unwrap incoming
                    (\resources ->
                        incoming
                            |> List.map
                                (\r ->
                                    let
                                        ( viewing, focus ) =
                                            getInfo resources r.number

                                        s =
                                            { r
                                                | viewing = viewing
                                                , logFocus = focus
                                            }
                                    in
                                    Just <| Maybe.withDefault s <| overwriteById s resources
                                )
                            |> List.filterMap identity
                    )
    in
    -- when not an automatic refresh, respect the url focus
    if not refresh then
        focus logFocus merged

    else
        merged


{-| isViewing : takes resources and resource number and returns the resource viewing state
-}
isViewing : WebData (Resources a) -> String -> Bool
isViewing resources number =
    resources
        |> RemoteData.withDefault []
        |> List.filter (\resource -> String.fromInt resource.number == number)
        |> List.map .viewing
        |> List.head
        |> Maybe.withDefault False


{-| toggleView : takes resources and resource number and toggles that resource viewing state
-}
toggleView : String -> Resources a -> Resources a
toggleView number =
    List.Extra.updateIf
        (\resource -> String.fromInt resource.number == number)
        (\resource -> { resource | viewing = not resource.viewing })


{-| setAllViews : takes resources and value and sets all resources viewing state
-}
setAllViews : Bool -> Resources a -> Resources a
setAllViews value =
    List.map (\resource -> { resource | viewing = value })


{-| expandActive : takes resources and sets resource viewing state if the resource is active
-}
expandActive : String -> Resources a -> Resources a
expandActive number resources =
    List.Extra.updateIf
        (\resource -> (String.fromInt resource.number == number) && (resource.status /= Vela.Pending))
        (\resource -> { resource | viewing = True })
        resources


{-| getInfo : takes resources and resource number and returns the resource update information
-}
getInfo : Resources a -> Int -> ( Bool, LogFocus )
getInfo resources number =
    resources
        |> List.filter (\resource -> resource.number == number)
        |> List.map (\resource -> ( resource.viewing, resource.logFocus ))
        |> List.head
        |> Maybe.withDefault ( False, ( Nothing, Nothing ) )
