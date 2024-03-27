{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Org exposing (Model, Msg, Props, layout, map)

import Components.Crumbs
import Components.Help
import Components.Nav
import Components.Tabs
import Components.Util
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, a, main_, text)
import Html.Attributes exposing (class)
import Layout exposing (Layout)
import Layouts.Default
import Route exposing (Route)
import Route.Path
import Shared
import Url exposing (Url)
import Utils.Helpers as Util
import View exposing (View)


{-| Props : alias for an object containing properties with a contentMsg.
-}
type alias Props contentMsg =
    { navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    , helpCommands : List Components.Help.Command
    , crumbs : List Components.Crumbs.Crumb
    , org : String
    }


{-| map : takes a function and a properties object and returns a new properties object;
map connects the page (msg1) to the layout (msg2).
-}
map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.navButtons
    , helpCommands = props.helpCommands
    , crumbs = props.crumbs
    , org = props.org
    }


{-| layout : takes in properties, shared model, route, and a content object and returns a default org layout.
-}
layout : Props contentMsg -> Shared.Model -> Route () -> Layout Layouts.Default.Props Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init shared route
        , update = update shared route
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withOnUrlChanged OnUrlChanged
        |> Layout.withParentProps
            { helpCommands = props.helpCommands
            }



-- MODEL


{-| Model : alias for a model object.
-}
type alias Model =
    { tabHistory : Dict String Url }


{-| init : takes in shared model, route, and a content object and returns a model and effect.
-}
init : Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init shared route _ =
    ( { tabHistory = Dict.empty
      }
    , Effect.getCurrentUser {}
    )



-- UPDATE


{-| Msg : possible messages for the default org layout.
-}
type Msg
    = OnUrlChanged { from : Route (), to : Route () }


{-| update : takes in shared model, route, message, and model and returns a new model and effect.
-}
update : Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- BROWSER
        OnUrlChanged options ->
            ( { model
                | tabHistory =
                    model.tabHistory |> Dict.insert (Route.Path.toString options.to.path) options.to.url
              }
            , Effect.replaceRouteRemoveTabHistorySkipDomFocus route
            )


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes in properties, shared model, route, and a content object and returns a view.
-}
view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title = props.org ++ " " ++ content.title
    , body =
        [ Components.Nav.view shared
            route
            { buttons =
                props.navButtons
                    ++ [ a
                            [ class "button"
                            , class "-outline"
                            , Util.testAttribute "source-repos"
                            , Route.Path.href Route.Path.AccountSourceRepos
                            ]
                            [ text "Source Repositories" ]
                       ]
            , crumbs = Components.Crumbs.view route.path props.crumbs
            }
        , main_ [ class "content-wrap" ]
            (Components.Util.view
                shared
                route
                (Components.Tabs.viewOrgTabs
                    shared
                    { org = props.org
                    , currentPath = route.path
                    , tabHistory = model.tabHistory
                    }
                    :: props.utilButtons
                )
                :: content.body
            )
        ]
    }
