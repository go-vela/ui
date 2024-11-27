{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Repo exposing (Model, Msg, Props, layout, map)

import Components.Crumbs
import Components.Favorites
import Components.Help
import Components.Nav
import Components.Tabs
import Components.Util
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, main_)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layout exposing (Layout)
import Layouts.Default
import RemoteData exposing (RemoteData, WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Url exposing (Url)
import Utils.Errors as Errors
import Utils.Favicons as Favicons
import Utils.Favorites as Favorites
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
        , update = update props route
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
    { tabHistory : Dict String Url, repo : WebData Vela.Repository }


{-| init : takes in properties, shared model, route, and a content object and returns a model and effect.
-}
init : Props contentMsg -> Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init props shared route _ =
    ( { tabHistory = Dict.empty
      , repo = RemoteData.NotAsked
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
      -- REPO
    | GetRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
      -- FAVORITES
    | ToggleFavorite String (Maybe String)
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes in properties, route, message, and model and returns a new model and effect.
-}
update : Props contentMsg -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update props route msg model =
    case msg of
        -- BROWSER
        OnUrlChanged options ->
            ( { model
                | tabHistory =
                    model.tabHistory |> Dict.insert (Route.Path.toString options.to.path) options.to.url
              }
            , Effect.replaceRouteRemoveTabHistorySkipDomFocus route
            )

        -- REPO
        GetRepoResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model
                        | repo = RemoteData.Success repo
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | repo = Errors.toFailure error }
                    , Effect.batch
                        [ Effect.handleHttpError
                            { error = error
                            , shouldShowAlertFn = Errors.showAlertAlways
                            }
                        , Effect.none
                        ]
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


toT : WebData Vela.Repository -> Html msg
toT data =
    case data of
        RemoteData.NotAsked ->
            Html.text ""

        RemoteData.Loading ->
            Html.text ""

        RemoteData.Failure _ ->
            Html.text ""

        RemoteData.Success r ->
            if r.install_id == 0 then
                installBanner r

            else
                Html.text ""


installBanner : Vela.Repository -> Html msg
installBanner repo =
    Html.div
        [ class "banner" ]
        [ Html.div [ Html.Attributes.class "warning" ]
            [ Html.text "Please "
            , Html.a
                [ Html.Attributes.href "https://git.target.com/github-apps/vela-local/installations/new"
                ]
                [ Html.text "install" ]
            , Html.text " the Vela GitHub App to this organization and make sure the repository is added."
            ]
        , Html.div []
            [ Html.text "If you've already added this repository to the installation, try clicking \"Sync Install\" in "
            , Html.a
                [ Route.Path.href <| Route.Path.Org__Repo__Settings { org = repo.org, repo = repo.name }
                ]
                [ Html.text "Settings" ]
            , Html.text "."
            ]
        ]


{-| view : takes in properties, shared model, route, and a content object and returns a view.
-}
view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title = props.org ++ "/" ++ props.repo ++ " " ++ content.title
    , body =
        [ Components.Nav.view shared
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
        , toT model.repo
        , main_ [ class "content-wrap" ]
            (Components.Util.view shared
                route
                (Components.Tabs.viewRepoTabs
                    shared
                    { org = props.org
                    , repo = props.repo
                    , currentPath = route.path
                    , tabHistory = model.tabHistory
                    }
                    :: props.utilButtons
                )
                :: content.body
            )
        ]
    }
