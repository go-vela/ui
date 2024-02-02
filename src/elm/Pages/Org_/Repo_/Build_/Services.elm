{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Services exposing (..)

import Auth
import Browser.Dom exposing (focus)
import Components.Logs
import Components.Svgs
import Debug exposing (log)
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, button, code, details, div, small, summary, text)
import Html.Attributes exposing (attribute, class, classList)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors
import Utils.Focus as Focus
import Utils.Helpers as Util
import Utils.Interval as Interval exposing (Interval)
import Utils.Logs as Logs
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
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org_Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "#" ++ route.params.buildNumber, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        , toBuildPath =
            \buildNumber ->
                Route.Path.Org_Repo_Build_Services
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        }



-- INIT


type alias Model =
    { services : WebData (List Vela.Service)
    , logs : Dict Int (WebData Vela.Log)
    , viewing : List Int
    , focus : Focus.Focus
    , logFollow : Int
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { services = RemoteData.Loading
      , logs = Dict.empty
      , viewing = []
      , focus = Focus.fromString route.hash
      , logFollow = 0
      }
    , Effect.batch
        [ Effect.getBuildServices
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetBuildServicesResponse
            , pageNumber = Nothing
            , perPage = Just 100
            , org = route.params.org
            , repo = route.params.repo
            , buildNumber = route.params.buildNumber
            }
        ]
    )



-- UPDATE


type Msg
    = NoOp
    | -- BROWSER
      OnHashChanged { from : Maybe String, to : Maybe String }
    | PushUrlHash { hash : String }
    | FocusOn { target : String }
      -- SERVICES
    | GetBuildServicesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Service ))
    | GetBuildServicesRefreshResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Service ))
    | GetBuildServiceLogResponse { service : Vela.Service, applyDomFocus : Bool, previousFocus : Maybe Focus.Focus } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | GetBuildServiceLogRefreshResponse { service : Vela.Service } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | ClickService { service : Vela.Service }
    | ExpandService { service : Vela.Service, applyDomFocus : Bool, previousFocus : Maybe Focus.Focus }
    | CollapseService { service : Vela.Service }
    | ExpandAll
    | CollapseAll
      -- LOGS
    | DownloadLog { filename : String, content : String, map : String -> String }
    | FollowLog { number : Int }
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval }


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )

        -- BROWSER
        OnHashChanged options ->
            let
                focus =
                    Focus.fromString options.to
            in
            ( { model
                | focus = focus
              }
            , RemoteData.withDefault [] model.services
                |> List.filter (\s -> Maybe.withDefault -1 focus.group == s.number)
                |> List.map (\s -> ExpandService { service = s, applyDomFocus = True, previousFocus = Just model.focus })
                |> List.map Effect.sendMsg
                |> Effect.batch
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
                    ( { model | services = RemoteData.succeed services }
                    , services
                        |> List.Extra.find (\service -> Maybe.withDefault -1 model.focus.group == service.number)
                        |> Maybe.map (\service -> service)
                        |> Maybe.map
                            (\service ->
                                ExpandService
                                    { service = service
                                    , applyDomFocus = True
                                    , previousFocus = Nothing
                                    }
                                    |> Effect.sendMsg
                            )
                        |> Maybe.withDefault Effect.none
                    )

                Err error ->
                    ( { model | services = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetBuildServicesRefreshResponse response ->
            case response of
                Ok ( _, services ) ->
                    ( { model | services = RemoteData.succeed services }
                    , services
                        |> List.filter (\service -> List.member service.number model.viewing)
                        |> List.map
                            (\service ->
                                Effect.getBuildServiceLog
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse = GetBuildServiceLogRefreshResponse { service = service }
                                    , org = route.params.org
                                    , repo = route.params.repo
                                    , buildNumber = route.params.buildNumber
                                    , serviceNumber = String.fromInt service.number
                                    }
                            )
                        |> Effect.batch
                    )

                Err error ->
                    ( { model | services = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetBuildServiceLogResponse options response ->
            case response of
                Ok ( _, log ) ->
                    ( { model
                        | logs =
                            Dict.update options.service.id
                                (Logs.safeDecodeLogData shared.velaLogBytesLimit log)
                                model.logs
                      }
                    , if options.applyDomFocus then
                        case ( model.focus.group, model.focus.a, model.focus.b ) of
                            ( Just g, Just _, Just _ ) ->
                                FocusOn
                                    { target =
                                        Focus.toDomTarget
                                            { group = Just g
                                            , a = Focus.lineNumberChanged options.previousFocus model.focus
                                            , b = Nothing
                                            }
                                    }
                                    |> Effect.sendMsg

                            ( Just g, Just a, _ ) ->
                                FocusOn
                                    { target =
                                        Focus.toDomTarget
                                            { group = Just g
                                            , a = Just a
                                            , b = Nothing
                                            }
                                    }
                                    |> Effect.sendMsg

                            _ ->
                                Effect.none

                      else
                        Effect.none
                    )

                Err error ->
                    ( { model | services = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetBuildServiceLogRefreshResponse options response ->
            case response of
                Ok ( _, log ) ->
                    let
                        changed =
                            Dict.get options.service.id model.logs
                                |> Maybe.Extra.unwrap log (RemoteData.withDefault log)
                                |> (\l -> l.rawData /= log.rawData)
                    in
                    ( { model
                        | logs =
                            Dict.update options.service.id
                                (Logs.safeDecodeLogData shared.velaLogBytesLimit log)
                                model.logs
                      }
                    , if model.logFollow == options.service.number && changed then
                        FocusOn { target = Logs.bottomTrackerFocusId (String.fromInt options.service.number) }
                            |> Effect.sendMsg

                      else
                        Effect.none
                    )

                Err error ->
                    ( { model | services = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        ClickService options ->
            ( model
            , if List.member options.service.number model.viewing then
                CollapseService { service = options.service }
                    |> Effect.sendMsg

              else
                Effect.batch
                    [ ExpandService { service = options.service, applyDomFocus = False, previousFocus = Nothing }
                        |> Effect.sendMsg
                    , case model.focus.a of
                        Nothing ->
                            PushUrlHash
                                { hash =
                                    Focus.toString
                                        { group = Just options.service.number
                                        , a = Nothing
                                        , b = Nothing
                                        }
                                }
                                |> Effect.sendMsg

                        _ ->
                            Effect.none
                    ]
            )

        ExpandService options ->
            ( { model
                | viewing = List.Extra.unique <| options.service.number :: model.viewing
              }
            , Effect.batch
                [ Effect.getBuildServiceLog
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse =
                        GetBuildServiceLogResponse
                            { service = options.service
                            , applyDomFocus = options.applyDomFocus
                            , previousFocus = options.previousFocus
                            }
                    , org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = route.params.buildNumber
                    , serviceNumber = String.fromInt options.service.number
                    }
                , if options.applyDomFocus then
                    case ( model.focus.group, model.focus.a, model.focus.b ) of
                        ( Just g, Nothing, Nothing ) ->
                            FocusOn
                                { target =
                                    Focus.toDomTarget
                                        { group = Just g
                                        , a = Nothing
                                        , b = Nothing
                                        }
                                }
                                |> Effect.sendMsg

                        _ ->
                            Effect.none

                  else
                    Effect.none
                ]
            )

        CollapseService options ->
            ( { model
                | viewing = List.Extra.remove options.service.number model.viewing
                , logs =
                    Dict.update options.service.id
                        (\_ -> Nothing)
                        model.logs
                , logFollow =
                    if model.logFollow == options.service.number then
                        0

                    else
                        model.logFollow
              }
            , Effect.none
            )

        ExpandAll ->
            ( model
            , model.services
                |> RemoteData.withDefault []
                |> List.map
                    (\service ->
                        ExpandService
                            { service = service
                            , applyDomFocus = False
                            , previousFocus = Nothing
                            }
                    )
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        CollapseAll ->
            ( model
            , model.services
                |> RemoteData.withDefault []
                |> List.map (\service -> CollapseService { service = service })
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

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getBuildServices
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetBuildServicesRefreshResponse
                , pageNumber = Nothing
                , perPage = Just 100
                , org = route.params.org
                , repo = route.params.repo
                , buildNumber = route.params.buildNumber
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = ""
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
                            [ button
                                [ class "button"
                                , class "-link"
                                , onClick CollapseAll
                                , Util.testAttribute "collapse-all"
                                ]
                                [ small [] [ text "collapse all" ] ]
                            , button
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
    div
        [ classList
            [ ( "service", True )
            , ( "flowline-left", True )
            ]
        , Util.testAttribute "service"
        ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ Components.Svgs.statusToIcon service.status ] ]
        , details
            (classList
                [ ( "details", True )
                , ( "-with-border", True )
                , ( "-running", service.status == Vela.Running )
                ]
                :: Util.open (List.member service.number model.viewing)
            )
            [ summary
                [ class "summary"
                , Util.testAttribute <| "service-header-" ++ String.fromInt service.number
                , onClick <| ClickService { service = service }
                , Focus.toAttr
                    { group = Just service.number
                    , a = Nothing
                    , b = Nothing
                    }
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
                , shift = shared.shift
                , log = log
                , org = route.params.org
                , repo = route.params.repo
                , buildNumber = route.params.buildNumber
                , resourceType = "service"
                , resourceNumber = String.fromInt service.number
                , focus = model.focus
                , follow = model.logFollow
                }
