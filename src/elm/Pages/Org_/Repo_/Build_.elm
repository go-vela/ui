{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_ exposing (..)

import Api.Pagination
import Auth
import Components.Logs
import Components.Pager
import Components.Steps
import Components.Svgs as SvgBuilder
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , div
        , span
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        , rows
        , scope
        )
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Utils.Errors as Errors
import Utils.Focus as Focus
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)
        |> Page.withOnHashChanged OnHashChanged



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, buildNumber : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        , toBuildPath =
            \buildNumber ->
                Route.Path.Org_Repo_Build_
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { steps : WebData (List Vela.Step)
    , logs : Dict Int (WebData Vela.Log)
    , logLineFocus : ( Maybe Int, ( Maybe Int, Maybe Int ) )
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { steps = RemoteData.Loading
      , logs = Dict.empty
      , logLineFocus =
            route.hash
                |> Focus.parseFocusFragment
                |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
      }
    , Effect.getBuildSteps
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetBuildStepsResponse
        , pageNumber = Nothing
        , perPage = Nothing
        , org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        }
    )



-- UPDATE


type Msg
    = OnHashChanged { from : Maybe String, to : Maybe String }
    | GetBuildStepsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Step ))
    | GetBuildStepLogResponse Vela.Step (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | ExpandStep Vela.Step
    | ExpandSteps
    | CollapseSteps
    | FocusLogLine String


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        OnHashChanged _ ->
            ( { model
                | logLineFocus =
                    route.hash
                        |> Focus.parseFocusFragment
                        |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
              }
            , Effect.none
            )

        GetBuildStepsResponse response ->
            case response of
                Ok ( _, steps ) ->
                    ( { model
                        | steps = RemoteData.Success steps
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetBuildStepLogResponse step response ->
            case response of
                Ok ( _, log ) ->
                    let
                        logs =
                            Dict.update step.id
                                (Components.Logs.safeDecodeLogData shared.velaLogBytesLimit log)
                                model.logs
                    in
                    ( { model | logs = logs }
                    , Effect.none
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        ExpandStep step ->
            -- let
            --                 build =
            --                     rm.build
            --                 ( steps, fetchStepLogs ) =
            --                     clickResource build.steps.steps stepNumber
            --                 action =
            --                     if fetchStepLogs then
            --                         getBuildStepLogs model org repo buildNumber stepNumber Nothing True
            --                     else
            --                         Cmd.none
            --                 stepOpened =
            --                     isViewing steps stepNumber
            --                 -- step clicked is step being followed
            --                 onFollowedStep =
            --                     build.steps.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)
            --                 follow =
            --                     if onFollowedStep && not stepOpened then
            --                         -- stop following a step when collapsed
            --                         0
            --                     else
            --                         build.steps.followingStep
            --             in
            --             ( { model | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing follow }
            --             , Cmd.batch <|
            --                 [ action
            --                 , if stepOpened then
            --                     Navigation.pushUrl model.navigationKey <| resourceFocusFragment "step" stepNumber []
            --                   else
            --                     Cmd.none
            --                 ]
            --             )
            ( model
            , Effect.getBuildStepLog
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = GetBuildStepLogResponse step
                , org = route.params.org
                , repo = route.params.repo
                , buildNumber = route.params.buildNumber
                , stepNumber = String.fromInt step.number
                }
            )

        ExpandSteps ->
            -- let
            --     steps =
            --         RemoteData.unwrap build.steps.steps
            --             (\steps_ -> steps_ |> setAllViews True |> RemoteData.succeed)
            --             build.steps.steps
            --     -- refresh logs for expanded steps
            --     sideEffects =
            --         getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            -- in
            -- ( { model | repo = updateBuildSteps steps rm }
            -- , sideEffects
            -- )
            ( model
            , Effect.none
            )

        CollapseSteps ->
            -- let
            --     steps =
            --         build.steps.steps
            --             |> RemoteData.unwrap build.steps.steps
            --                 (\steps_ -> steps_ |> setAllViews False |> RemoteData.succeed)
            -- in
            -- ( { model | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing 0 }
            ( model
            , Effect.none
            )

        FocusLogLine line ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org_Repo_Build_
                        { org = route.params.org
                        , repo = route.params.repo
                        , buildNumber = route.params.buildNumber
                        }
                , query = route.query
                , hash = Just <| String.dropLeft 1 line
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = "#" ++ route.params.buildNumber
    , body =
        [ Components.Steps.view
            shared
            { msgs =
                { expandStep = ExpandStep
                , expandSteps = ExpandSteps
                , collapseSteps = CollapseSteps
                , focusLogLine = FocusLogLine
                }
            , steps = model.steps
            , logs = model.logs
            , org = route.params.org
            , repo = route.params.repo
            , buildNumber = route.params.buildNumber
            , logLineFocus = model.logLineFocus
            }
        ]
    }
