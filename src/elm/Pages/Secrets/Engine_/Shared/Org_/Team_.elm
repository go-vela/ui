{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Shared.Org_.Team_ exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Crumbs
import Components.Nav
import Components.Pager
import Components.Secrets
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (a, main_, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Time
import Utils.Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String, team : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String, team : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "List Shared Secrets Help"
              , content = "vela get secrets -h"
              , docs = Just "secret/get"
              }
            , { name = "List Shared Secrets"
              , content =
                    "vela get secrets --secret.engine native --secret.type shared --org "
                        ++ route.params.org
                        ++ " --team '*'"
              , docs = Just "secret/get"
              }
            ]
        }



-- INIT


type alias Model =
    { sharedSecrets : WebData (List Vela.Secret)
    , pager : List WebLink
    }


init : Shared.Model -> Route { engine : String, org : String, team : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { sharedSecrets = RemoteData.Loading
      , pager = []
      }
    , Effect.getSharedSecrets
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetSharedSecretsResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , engine = route.params.engine
        , org = route.params.org
        , team = route.params.team
        }
    )



-- UPDATE


type Msg
    = -- SECRETS
      GetSharedSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GotoPage Int
      -- ALERTS
    | AddAlertCopiedToClipboard String
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { engine : String, org : String, team : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SECRETS
        GetSharedSecretsResponse response ->
            case response of
                Ok ( meta, secrets ) ->
                    ( { model
                        | sharedSecrets = RemoteData.Success secrets
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | sharedSecrets = Utils.Errors.toFailure error }
                    , Effect.none
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
                , Effect.getSharedSecrets
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetSharedSecretsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , engine = route.params.engine
                    , org = route.params.org
                    , team = route.params.team
                    }
                ]
            )

        -- ALERTS
        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess
                -- todo: this gets crazy when you copy things that dont render
                { content = "'" ++ contentCopied ++ "' copied to clipboard."
                , addToastIfUnique = False
                , link = Nothing
                }
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getSharedSecrets
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetSharedSecretsResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                , engine = route.params.engine
                , org = route.params.org
                , team = route.params.team
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { engine : String, org : String, team : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.team, Nothing )
            , ( "Secrets", Nothing )
            ]
    in
    { title = "Secrets" ++ Util.pageToString (Dict.get "page" route.query)
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ Components.Secrets.viewSharedSecrets shared
                { msgs =
                    { showCopyAlert = AddAlertCopiedToClipboard
                    }
                , engine = route.params.engine
                , key = route.params.org ++ "/" ++ route.params.team
                , secrets = model.sharedSecrets
                , tableButtons =
                    Just
                        [ a
                            [ class "button"
                            , class "-outline"
                            , class "button-with-icon"
                            , Util.testAttribute "add-shared-secret"
                            , Route.Path.href <|
                                Route.Path.SecretsEngine_SharedOrg_Team_Add { engine = route.params.engine, org = route.params.org, team = route.params.team }
                            ]
                            [ text "Add Shared Secret"
                            , FeatherIcons.plus
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                            ]
                        , Components.Pager.view
                            { show = True
                            , links = model.pager
                            , labels = Components.Pager.defaultLabels
                            , msg = GotoPage
                            }
                        ]
                }
            ]
        ]
    }
