{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Graph exposing (..)

import Auth
import Components.Logs
import Components.Svgs
import Debug exposing (log)
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, code, details, div, small, summary, text)
import Html.Attributes exposing (attribute, class, id)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Errors
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
                Route.Path.Org_Repo_Build_Services
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { services : WebData (List Vela.Service)
    , logs : Dict Int (WebData Vela.Log)
    , lineFocus : ( Maybe Int, ( Maybe Int, Maybe Int ) )
    , logFollow : Int
    }



-- type alias BuildGraphModel =
--     { buildNumber : BuildNumber
--     , graph : WebData BuildGraph
--     , rankdir : DOT.Rankdir
--     , filter : String
--     , focusedNode : Int
--     , showServices : Bool
--     , showSteps : Bool
--     }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { services = RemoteData.Loading
      , logs = Dict.empty
      , lineFocus =
            route.hash
                |> Focus.parseResourceFocusTargetFromFragment
                |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
      , logFollow = 0
      }
    , Effect.getBuildServices
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetBuildServicesResponse
        , pageNumber = Nothing
        , perPage = Nothing
        , org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        }
    )



-- UPDATE


type Msg
    = -- BROWSER
      OnHashChanged { from : Maybe String, to : Maybe String }
    | PushUrlHash { hash : String }
    | FocusOn { target : String }
      -- SERVICES
    | GetBuildServicesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Service ))
    | GetBuildServiceLogResponse Vela.Service (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | ExpandService { service : Vela.Service, updateUrlHash : Bool }
    | CollapseService { service : Vela.Service, updateUrlHash : Bool }
    | ExpandAll
    | CollapseAll
      -- LOGS
    | DownloadLog { filename : String, content : String, map : String -> String }
    | FollowLog { number : Int }


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- BROWSER
        OnHashChanged _ ->
            ( { model
                | lineFocus =
                    route.hash
                        |> Focus.parseResourceFocusTargetFromFragment
                        |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
              }
            , Effect.none
            )

        PushUrlHash options ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org_Repo_Build_Services
                        { org = route.params.org
                        , repo = route.params.repo
                        , buildNumber = route.params.buildNumber
                        }
                , query = route.query
                , hash = Just options.hash
                }
            )

        FocusOn options ->
            ( model, Effect.focusOn options )

        -- SERVICES
        GetBuildServicesResponse response ->
            case response of
                Ok ( _, services ) ->
                    let
                        ( services_, sideEffects ) =
                            services
                                |> List.map
                                    (\service ->
                                        case model.lineFocus of
                                            ( Just resourceNumber, _ ) ->
                                                if service.number == resourceNumber then
                                                    ( { service | viewing = True }
                                                    , ExpandService { service = service, updateUrlHash = False }
                                                        |> Effect.sendMsg
                                                    )

                                                else
                                                    ( { service | viewing = False }, Effect.none )

                                            _ ->
                                                ( { service | viewing = False }, Effect.none )
                                    )
                                |> List.unzip
                                |> Tuple.mapFirst RemoteData.succeed
                                |> Tuple.mapSecond Effect.batch
                    in
                    ( { model
                        | services =
                            services_
                      }
                    , sideEffects
                    )

                Err error ->
                    ( { model | services = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetBuildServiceLogResponse service response ->
            case response of
                Ok ( _, log ) ->
                    let
                        logs =
                            Dict.update service.id
                                (Components.Logs.safeDecodeLogData shared.velaLogBytesLimit log)
                                model.logs
                    in
                    ( { model | logs = logs }
                    , Effect.none
                    )

                Err error ->
                    ( { model | services = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        ExpandService options ->
            ( { model
                | services =
                    case model.services of
                        RemoteData.Success services ->
                            List.Extra.updateIf
                                (\s -> s.id == options.service.id)
                                (\s -> { s | viewing = True })
                                services
                                |> RemoteData.succeed

                        _ ->
                            model.services
              }
            , Effect.batch
                [ Effect.getBuildServiceLog
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetBuildServiceLogResponse options.service
                    , org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = route.params.buildNumber
                    , serviceNumber = String.fromInt options.service.number
                    }
                , if options.updateUrlHash then
                    Effect.pushRoute
                        { path =
                            Route.Path.Org_Repo_Build_Services
                                { org = route.params.org
                                , repo = route.params.repo
                                , buildNumber = route.params.buildNumber
                                }
                        , query = route.query
                        , hash = Just <| "service:" ++ String.fromInt options.service.number
                        }

                  else
                    Effect.none
                ]
            )

        CollapseService options ->
            ( { model
                | services =
                    case model.services of
                        RemoteData.Success services ->
                            List.Extra.updateIf
                                (\s -> s.id == options.service.id)
                                (\s -> { s | viewing = False })
                                services
                                |> RemoteData.succeed

                        _ ->
                            model.services
              }
            , Effect.none
            )

        ExpandAll ->
            ( model
            , model.services
                |> RemoteData.withDefault []
                |> List.map (\service -> ExpandService { service = service, updateUrlHash = False })
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        CollapseAll ->
            ( model
            , model.services
                |> RemoteData.withDefault []
                |> List.map (\service -> CollapseService { service = service, updateUrlHash = False })
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        -- LOGS
        DownloadLog options ->
            ( model
            , Effect.downloadFile options
            )

        FollowLog options ->
            ( { model | logFollow = options.number }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = "Graph"
    , body =
        [ case model.services of
            RemoteData.Success services ->
                if List.length services > 0 then
                    div []
                        [ div
                            [ class "buttons"
                            , class "log-actions"
                            , class "flowline-left"
                            , Util.testAttribute "log-actions"
                            ]
                            [ Html.button
                                [ class "button"
                                , class "-link"
                                , onClick CollapseAll
                                , Util.testAttribute "collapse-all"
                                ]
                                [ small [] [ text "collapse all" ] ]
                            , Html.button
                                [ class "button"
                                , class "-link"
                                , onClick ExpandAll
                                , Util.testAttribute "expand-all"
                                ]
                                [ small [] [ text "expand all" ] ]
                            ]
                        , div [ class "services" ]
                            [ div [ class "-items", Util.testAttribute "services" ] <|
                                List.map (viewService shared model route) <|
                                    List.sortBy .number <|
                                        RemoteData.withDefault [] model.services
                            ]
                        ]

                else
                    div [ class "no-services" ] [ small [] [ code [] [ text "No services found for this pipeline." ] ] ]

            _ ->
                Util.smallLoader
        ]
    }


viewService : Shared.Model -> Model -> Route { org : String, repo : String, buildNumber : String } -> Vela.Service -> Html Msg
viewService shared model route service =
    let
        serviceNumber =
            String.fromInt service.number

        clickService =
            if service.viewing then
                CollapseService

            else
                ExpandService
    in
    div [ Html.Attributes.classList [ ( "service", True ), ( "flowline-left", True ) ], Util.testAttribute "service" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ Components.Svgs.statusToIcon service.status ] ]
        , details
            (Html.Attributes.classList
                [ ( "details", True )
                , ( "-with-border", True )
                , ( "-running", service.status == Vela.Running )
                ]
                :: Util.open service.viewing
            )
            [ summary
                [ class "summary"
                , Util.testAttribute <| "service-header-" ++ serviceNumber
                , onClick <| clickService { service = service, updateUrlHash = True }
                , id <| "service-" ++ serviceNumber
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text service.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime shared.time service.started service.finished ]
                    ]
                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml [ attribute "aria-label" "show build actions" ]
                ]
            , div [ class "logs-container" ]
                [ viewLogs shared model route service <|
                    Maybe.withDefault RemoteData.Loading <|
                        Dict.get service.id model.logs
                ]
            ]
        ]


viewLogs : Shared.Model -> Model -> Route { org : String, repo : String, buildNumber : String } -> Vela.Service -> WebData Vela.Log -> Html Msg
viewLogs shared model route service log =
    case service.status of
        Vela.Error ->
            div [ class "message", class "error", Util.testAttribute "resource-error" ]
                [ text <|
                    "error: "
                        ++ (if String.isEmpty service.error then
                                "null"

                            else
                                service.error
                           )
                ]

        Vela.Killed ->
            div [ class "message", class "error", Util.testAttribute "service-skipped" ]
                [ text "service was skipped" ]

        _ ->
            Components.Logs.view
                shared
                { msgs =
                    { pushUrlHash = PushUrlHash
                    , focusOn = FocusOn
                    , download = DownloadLog
                    , follow = FollowLog
                    }
                , log = log
                , org = route.params.org
                , repo = route.params.repo
                , buildNumber = route.params.buildNumber
                , resourceType = "service"
                , resourceNumber = String.fromInt service.number
                , lineFocus =
                    if service.number == Maybe.withDefault -1 (Tuple.first model.lineFocus) then
                        Just <| Tuple.second model.lineFocus

                    else
                        Nothing
                , follow = model.logFollow
                }
