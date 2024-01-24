{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Secrets exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Pager
import Components.Secrets
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (a, text)
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
import Utils.Errors
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { org = route.params.org
        , repo = route.params.repo
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { secrets : WebData (List Vela.Secret)
    , pager : List WebLink
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { secrets = RemoteData.Loading
      , pager = []
      }
    , Effect.getRepoSecrets
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoSecretsResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetRepoSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GotoPage Int
    | AddAlertCopiedToClipboard String


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetRepoSecretsResponse response ->
            case response of
                Ok ( meta, secrets ) ->
                    ( { model
                        | secrets = RemoteData.Success secrets
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | secrets = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
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
                , Effect.getRepoSecrets
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetRepoSecretsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess { content = contentCopied, addToastIfUnique = False }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Secrets"
    , body =
        [ Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        , Components.Secrets.viewRepoSecrets shared
            { msgs =
                { showCopyAlert = AddAlertCopiedToClipboard
                }
            , secrets = model.secrets
            , tableButtons =
                Just
                    [ a
                        [ class "button"
                        , class "-outline"
                        , Route.Path.href <|
                            Route.Path.Org_Secrets { org = route.params.org }
                        , Util.testAttribute "manage-org-secrets"
                        ]
                        [ text "Manage Org Secrets" ]
                    , a
                        [ class "button"
                        , class "-outline"
                        , class "button-with-icon"
                        , Util.testAttribute "add-repo-secret"
                        , Route.Path.href <|
                            Route.Path.Org_Repo_SecretsAdd { org = route.params.org, repo = route.params.repo }
                        ]
                        [ text "Add Repo Secret"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    ]
            }
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }
