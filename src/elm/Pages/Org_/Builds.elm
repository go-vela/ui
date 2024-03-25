{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Builds exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Build
import Components.Builds
import Components.Pager
import Dict
import Effect exposing (Effect)
import Html exposing (caption, div, span)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)
        |> Page.withOnQueryParameterChanged { key = "event", onChange = OnEventQueryParameterChanged }



-- LAYOUT


toLayout : Auth.User -> Route { org : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Org
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Nothing )
            ]
        , org = route.params.org
        }



-- INIT


type alias Model =
    { builds : WebData (List Vela.Build)
    , pager : List WebLink
    , showFullTimestamps : Bool
    , showActionsMenus : List Int
    , showFilter : Bool
    }


init : Shared.Model -> Route { org : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { builds = RemoteData.Loading
      , pager = []
      , showFullTimestamps = False
      , showActionsMenus = []
      , showFilter = False
      }
    , Effect.getOrgBuilds
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetOrgBuildsResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , maybeEvent = Dict.get "event" route.query
        , org = route.params.org
        }
    )



-- UPDATE


type Msg
    = --BROWSER
      OnEventQueryParameterChanged { from : Maybe String, to : Maybe String }
      -- BUILDS
    | GetOrgBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))
    | GotoPage Int
    | RestartBuild { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber }
    | RestartBuildResponse { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | CancelBuild { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber }
    | CancelBuildResponse { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | ApproveBuild { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber }
    | ApproveBuildResponse { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | ShowHideActionsMenus (Maybe Int) (Maybe Bool)
    | FilterByEvent (Maybe String)
    | ShowHideFullTimestamps
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { org : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- BROWSER
        OnEventQueryParameterChanged options ->
            ( model
            , Effect.getOrgBuilds
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetOrgBuildsResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                , maybeEvent = options.to
                , org = route.params.org
                }
            )

        -- BUILDS
        GetOrgBuildsResponse response ->
            case response of
                Ok ( meta, builds ) ->
                    ( { model
                        | builds = RemoteData.Success builds
                        , pager = Api.Pagination.get meta.headers
                        , showFilter = List.length builds > 0 || Dict.get "event" route.query /= Nothing
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | builds = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.pushRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getOrgBuilds
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetOrgBuildsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , maybeEvent = Dict.get "event" route.query
                    , org = route.params.org
                    }
                ]
            )

        RestartBuild options ->
            ( { model | showActionsMenus = [] }
            , Effect.restartBuild
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = RestartBuildResponse options
                , org = options.org
                , repo = options.repo
                , buildNumber = options.buildNumber
                }
            )

        RestartBuildResponse options response ->
            case response of
                Ok ( _, build ) ->
                    let
                        newBuildLink =
                            Just
                                ( "View Build #" ++ String.fromInt build.number
                                , Route.Path.Org_Repo_Build_
                                    { org = options.org
                                    , repo = options.repo
                                    , buildNumber = String.fromInt build.number
                                    }
                                )
                    in
                    ( model
                    , Effect.batch
                        [ Effect.getOrgBuilds
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetOrgBuildsResponse
                            , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                            , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                            , maybeEvent = Dict.get "event" route.query
                            , org = route.params.org
                            }
                        , Effect.addAlertSuccess
                            { content = "Restarted build " ++ String.join "/" [ options.org, options.repo, options.buildNumber ] ++ "."
                            , addToastIfUnique = True
                            , link = newBuildLink
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        CancelBuild options ->
            ( { model | showActionsMenus = [] }
            , Effect.cancelBuild
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = CancelBuildResponse options
                , org = options.org
                , repo = options.repo
                , buildNumber = options.buildNumber
                }
            )

        CancelBuildResponse options response ->
            case response of
                Ok ( _, build ) ->
                    ( model
                    , Effect.batch
                        [ Effect.getOrgBuilds
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetOrgBuildsResponse
                            , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                            , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                            , maybeEvent = Dict.get "event" route.query
                            , org = route.params.org
                            }
                        , Effect.addAlertSuccess
                            { content = "Canceled build " ++ String.join "/" [ options.org, options.repo, options.buildNumber ] ++ "."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        ApproveBuild options ->
            ( { model | showActionsMenus = [] }
            , Effect.approveBuild
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = ApproveBuildResponse options
                , org = options.org
                , repo = options.repo
                , buildNumber = options.buildNumber
                }
            )

        ApproveBuildResponse options response ->
            case response of
                Ok ( _, build ) ->
                    ( model
                    , Effect.batch
                        [ Effect.getOrgBuilds
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetOrgBuildsResponse
                            , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                            , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                            , maybeEvent = Dict.get "event" route.query
                            , org = route.params.org
                            }
                        , Effect.addAlertSuccess
                            { content = "Approved build " ++ String.join "/" [ options.org, options.repo, options.buildNumber ] ++ "."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        ShowHideActionsMenus build show ->
            let
                buildsOpen =
                    model.showActionsMenus

                replaceList id buildList =
                    if List.member id buildList then
                        []

                    else
                        [ id ]

                updatedOpen =
                    Maybe.Extra.unwrap []
                        (\b ->
                            Maybe.Extra.unwrap
                                (replaceList b buildsOpen)
                                (\_ -> buildsOpen)
                                show
                        )
                        build
            in
            ( { model
                | showActionsMenus = updatedOpen
              }
            , Effect.none
            )

        FilterByEvent maybeEvent ->
            ( { model
                | builds = RemoteData.Loading
                , pager = []
              }
            , Effect.batch
                [ Effect.pushRoute
                    { path = route.path
                    , query =
                        route.query
                            |> Dict.update "page" (\_ -> Nothing)
                            |> Dict.update "event" (\_ -> maybeEvent)
                    , hash = route.hash
                    }
                , Effect.getOrgBuilds
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetOrgBuildsResponse
                    , pageNumber = Nothing
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , maybeEvent = maybeEvent
                    , org = route.params.org
                    }
                ]
            )

        ShowHideFullTimestamps ->
            ( { model | showFullTimestamps = not model.showFullTimestamps }, Effect.none )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getOrgBuilds
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetOrgBuildsResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                , maybeEvent = Dict.get "event" route.query
                , org = route.params.org
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Util.onMouseDownSubscription "build-actions" (List.length model.showActionsMenus > 0) (ShowHideActionsMenus Nothing)
        , Interval.tickEveryFiveSeconds Tick
        ]



-- VIEW


view : Shared.Model -> Route { org : String } -> Model -> View Msg
view shared route model =
    let
        msgs =
            { approveBuild = ApproveBuild
            , restartBuild = RestartBuild
            , cancelBuild = CancelBuild
            , showHideActionsMenus = ShowHideActionsMenus
            }
    in
    { title = "Builds" ++ Util.pageToString (Dict.get "page" route.query)
    , body =
        [ Components.Builds.viewHeader
            { show = model.showFilter
            , maybeEvent = Dict.get "event" route.query
            , showFullTimestamps = model.showFullTimestamps
            , filterByEvent = FilterByEvent
            , showHideFullTimestamps = ShowHideFullTimestamps
            }
        , caption
            [ class "builds-caption"
            ]
            [ span [] []
            , div [ class "buttons" ]
                [ Components.Pager.view
                    { show = RemoteData.unwrap False (\builds -> List.length builds > 0) model.builds
                    , links = model.pager
                    , labels = Components.Pager.defaultLabels
                    , msg = GotoPage
                    }
                ]
            ]
        , Components.Builds.view shared
            { msgs = msgs
            , builds = model.builds
            , orgRepo = ( route.params.org, Nothing )
            , maybeEvent = Dict.get "event" route.query
            , showFullTimestamps = model.showFullTimestamps
            , viewActionsMenu =
                \options ->
                    Components.Build.viewActionsMenu
                        { msgs =
                            { showHideActionsMenus = ShowHideActionsMenus
                            , restartBuild = RestartBuild
                            , cancelBuild = CancelBuild
                            , approveBuild = ApproveBuild
                            }
                        , build = options.build
                        , showActionsMenus = model.showActionsMenus
                        }
            , showRepoLink = True
            , linkBuildNumber = True
            }
        , Components.Pager.view
            { show = RemoteData.unwrap False (\builds -> List.length builds > 0) model.builds
            , links = model.pager
            , labels = Components.Pager.defaultLabels
            , msg = GotoPage
            }
        ]
    }
