{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Repo exposing (Model, Msg, Props, layout, map)

import Components.Crumbs
import Components.Favorites
import Components.Help
import Components.Loading
import Components.Nav
import Components.Tabs
import Components.Util
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, a, button, div, main_, p, span, text)
import Html.Attributes exposing (class, classList, disabled)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layout exposing (Layout)
import Layouts.Default
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Url exposing (Url)
import Utils.Errors as Errors
import Utils.Favicons as Favicons
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


{-| Props : alias for an object representing properties for the default repo layout.
-}
type alias Props contentMsg =
    { navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    , helpCommands : List Components.Help.Command
    , crumbs : List Components.Crumbs.Crumb
    , org : String
    , repo : String
    }


{-| map : takes a function and a properties object and returns a new properties object;
map connects the page (msg1) to the layout (msg2).
-}
map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    , helpCommands = props.helpCommands
    , crumbs = props.crumbs
    , org = props.org
    , repo = props.repo
    }


{-| layout : takes in properties, shared model, route, and a content object and returns a default repo layout.
-}
layout : Props contentMsg -> Shared.Model -> Route () -> Layout Layouts.Default.Props Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init props shared route
        , update = update props shared route
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withOnUrlChanged OnUrlChanged
        |> Layout.withParentProps
            { helpCommands = props.helpCommands
            }



-- MODEL


{-| Model : alias for a model object for the default repo layout.
-}
type alias Model =
    { tabHistory : Dict String Url
    , repo : WebData Vela.Repository
    , enablingRepo : Bool
    }


{-| init : takes in properties, shared model, route, and a content object and returns a model and effect.
-}
init : Props contentMsg -> Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init props shared route _ =
    ( { tabHistory = Dict.empty
      , repo = RemoteData.Loading
      , enablingRepo = False
      }
    , Effect.batch
        [ Effect.updateFavicon { favicon = Favicons.defaultFavicon }
        , Effect.getCurrentUserShared {}
        , Effect.getRepo
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetRepoResponse
            , org = props.org
            , repo = props.repo
            }
        , Effect.getRepoBuildsShared
            { pageNumber = Nothing
            , perPage = Nothing
            , maybeEvent = Nothing
            , maybeAfter = Nothing
            , org = props.org
            , repo = props.repo
            }
        , Effect.getRepoHooksShared
            { pageNumber = Nothing
            , perPage = Nothing
            , maybeEvent = Nothing
            , org = props.org
            , repo = props.repo
            }
        ]
    )



-- UPDATE


{-| Msg : possible messages for the default repo layout.
-}
type Msg
    = -- BROWSER
      OnUrlChanged { from : Route (), to : Route () }
      -- FAVORITES
    | ToggleFavorite String (Maybe String)
      -- REPO
    | GetRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | EnableRepo { org : String, repo : String }
    | EnableRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes in properties, shared model, route, message, and model and returns a new model and effect.
-}
update : Props contentMsg -> Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update props shared route msg model =
    case msg of
        -- BROWSER
        OnUrlChanged options ->
            ( { model
                | tabHistory =
                    model.tabHistory |> Dict.insert (Route.Path.toString options.to.path) options.to.url
              }
            , Effect.replaceRouteRemoveTabHistorySkipDomFocus route
            )

        -- FAVORITES
        ToggleFavorite org maybeRepo ->
            ( model
            , Effect.updateFavorite
                { org = org
                , maybeRepo = maybeRepo
                , updateType = Favorites.Toggle
                }
            )

        -- REPO
        GetRepoResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model | repo = RemoteData.succeed repo }
                    , Effect.none
                    )

                Err error ->
                    let
                        keepEnabledRepoState =
                            case ( error, model.repo ) of
                                ( Http.Detailed.BadStatus metadata _, RemoteData.Success _ ) ->
                                    metadata.statusCode == 404

                                _ ->
                                    False
                    in
                    if keepEnabledRepoState then
                        ( model, Effect.none )

                    else
                        ( { model | repo = Errors.toFailure error }
                        , Effect.handleHttpError
                            { error = error
                            , shouldShowAlertFn = Errors.showAlertNon404
                            }
                        )

        EnableRepo options ->
            let
                payload : Vela.EnableRepoPayload
                payload =
                    { org = options.org
                    , name = options.repo
                    , full_name = options.org ++ "/" ++ options.repo
                    , link = ""
                    , clone = ""
                    , private = False
                    , trusted = False
                    , active = True
                    , allowEvents = Vela.defaultAllowEvents
                    }

                body : Http.Body
                body =
                    Http.jsonBody <| Vela.encodeEnableRepository payload
            in
            ( { model | enablingRepo = True }
            , Effect.enableRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = EnableRepoResponse
                , body = body
                }
            )

        EnableRepoResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model | enablingRepo = False, repo = RemoteData.succeed repo }
                    , Effect.batch
                        [ Effect.addAlertSuccess
                            { content = repo.org ++ "/" ++ repo.name ++ " has been enabled."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        , Effect.updateFavorite { org = repo.org, maybeRepo = Just repo.name, updateType = Favorites.Add }
                        , Effect.updateRepoBuildsShared { builds = RemoteData.succeed [] }
                        , Effect.getRepoBuildsShared
                            { pageNumber = Nothing
                            , perPage = Nothing
                            , maybeEvent = Nothing
                            , maybeAfter = Nothing
                            , org = repo.org
                            , repo = repo.name
                            }
                        ]
                    )

                Err error ->
                    ( { model | enablingRepo = False }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- REFRESH
        Tick options ->
            let
                -- the hooks page has its own refresh call for hooks;
                -- this is to prevent double calls
                isNotOnHooksPage =
                    route.path /= Route.Path.Org__Repo__Hooks { org = props.org, repo = props.repo }

                runEffect =
                    if isNotOnHooksPage then
                        Effect.getRepoHooksShared
                            { pageNumber = Nothing
                            , perPage = Nothing
                            , maybeEvent = Nothing
                            , org = props.org
                            , repo = props.repo
                            }

                    else
                        Effect.none
            in
            ( model
            , runEffect
            )


{-| subscriptions : takes model and returns the subscriptions for auto refreshing the page.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes in properties, shared model, route, and a content object and returns a view.
-}
view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    let
        nav =
            Components.Nav.view shared
                route
                { buttons =
                    (Components.Favorites.viewStarToggle
                        { org = props.org
                        , repo = props.repo
                        , user = shared.user
                        , msg = ToggleFavorite
                        }
                        |> Html.map toContentMsg
                    )
                        :: props.navButtons
                , crumbs = Components.Crumbs.view route.path props.crumbs
                }

        tabs =
            Components.Tabs.viewRepoTabs
                shared
                { org = props.org
                , repo = props.repo
                , currentPath = route.path
                , tabHistory = model.tabHistory
                }

        body =
            case model.repo of
                RemoteData.Loading ->
                    [ Components.Loading.viewSmallLoader ]

                RemoteData.Failure error ->
                    case error of
                        Http.BadStatus 404 ->
                            [ viewNotEnabled props model toContentMsg ]

                        _ ->
                            content.body

                _ ->
                    content.body
    in
    { title = props.org ++ "/" ++ props.repo ++ " " ++ content.title
    , body =
        [ nav
        , main_ [ class "content-wrap" ]
            (Components.Util.view shared
                route
                (tabs :: props.utilButtons)
                :: body
            )
        ]
    }


{-| viewNotEnabled : renders empty state when a repo has not been enabled in Vela yet.
-}
viewNotEnabled : Props contentMsg -> Model -> (Msg -> contentMsg) -> Html contentMsg
viewNotEnabled props model toContentMsg =
    div [ class "overview", Util.testAttribute "repo-not-enabled" ]
        [ p []
            [ text "This repository may not be enabled yet. Enable it to start tracking builds." ]
        , button
            [ classList
                [ ( "button", True )
                , ( "-outline", model.enablingRepo )
                , ( "-loading", model.enablingRepo )
                ]
            , onClick (toContentMsg (EnableRepo { org = props.org, repo = props.repo }))
            , disabled model.enablingRepo
            , Util.testAttribute "enable-repo-button"
            ]
            [ if model.enablingRepo then
                text "Enabling"

              else
                text "Enable Repository"
            , if model.enablingRepo then
                span [ class "loading-ellipsis" ] []

              else
                text ""
            ]
        , p []
            [ text "Or "
            , a [ Route.Path.href Route.Path.Account_SourceRepos ] [ text "view all available repositories" ]
            , text "."
            ]
        ]
