{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Repo.Org_.Repo_.Add exposing (Model, Msg, page, view)

import Auth
import Components.Crumbs
import Components.Form
import Components.Nav
import Components.SecretForm
import Effect exposing (Effect)
import Html exposing (div, h2, main_, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela exposing (defaultSecretPayload)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "Add Repo Secret Help"
              , content = "vela add secret -h"
              , docs = Just "secret/add"
              }
            , { name = "Add Repo Secret Example"
              , content =
                    "vela add secret --secret.engine native --secret.type repo --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --name foo --value bar --event push"
              , docs = Just "secret/add"
              }
            ]
        }



-- INIT


type alias Model =
    { name : String
    , value : String
    , allowEvents : Vela.AllowEvents
    , images : List String
    , image : String
    , allowCommand : Bool
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { name = ""
      , value = ""
      , allowEvents = Vela.defaultEnabledAllowEvents
      , images = []
      , image = ""
      , allowCommand = True
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = -- SECRETS
      AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | AllowEventsUpdate { allowEvents : Vela.AllowEvents, event : String } Bool
    | SubmitForm


update : Shared.Model -> Route { engine : String, org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SECRETS
        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( { name = ""
                      , value = ""
                      , allowEvents = Vela.defaultEnabledAllowEvents
                      , images = []
                      , image = ""
                      , allowCommand = True
                      }
                    , Effect.addAlertSuccess
                        { content = secret.name ++ " added to repo secrets."
                        , addToastIfUnique = True
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        NameOnInput val ->
            ( { model | name = val }
            , Effect.none
            )

        ValueOnInput val ->
            ( { model | value = val }
            , Effect.none
            )

        ImageOnInput val ->
            ( { model | image = val }
            , Effect.none
            )

        AddImage image ->
            ( { model
                | images =
                    model.images
                        |> List.append [ image ]
                        |> List.Extra.unique
                , image = ""
              }
            , Effect.none
            )

        RemoveImage image ->
            ( { model
                | images =
                    model.images
                        |> List.filter ((/=) image)
              }
            , Effect.none
            )

        AllowCommandsOnClick val ->
            ( model
                |> (\m -> { m | allowCommand = Util.yesNoToBool val })
            , Effect.none
            )

        AllowEventsUpdate options val ->
            ( Vela.setAllowEvents model options.event val
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultSecretPayload
                        | type_ = Just Vela.RepoSecret
                        , org = Just route.params.org
                        , repo = Just route.params.repo
                        , team = Nothing
                        , name = Util.stringToMaybe model.name
                        , value = Util.stringToMaybe model.value
                        , images = Just model.images
                        , allowCommand = Just model.allowCommand
                        , allowEvents = Just model.allowEvents
                    }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.addRepoSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = AddSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { engine : String, org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org_Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "Repo Secrets", Just <| Route.Path.SecretsEngine_RepoOrg_Repo_ { org = route.params.org, repo = route.params.repo, engine = route.params.engine } )
            , ( "Add", Nothing )
            ]
    in
    { title = "Add Secret"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
                [ div []
                    [ h2 [] [ text <| String.Extra.toTitleCase "add repo secret" ]
                    , div [ class "secret-form" ]
                        [ Components.Form.viewInput
                            { title = Just "Name"
                            , subtitle = Nothing
                            , id_ = "name"
                            , val = model.name
                            , placeholder_ = "Secret Name"
                            , classList_ = [ ( "secret-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = NameOnInput
                            , disabled_ = False
                            }
                        , Components.Form.viewTextarea
                            { title = Just "Value"
                            , subtitle = Nothing
                            , id_ = "value"
                            , val = model.value
                            , placeholder_ = "Secret Value"
                            , classList_ = [ ( "secret-value", True ) ]
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = ValueOnInput
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewAllowEventsSelect
                            shared
                            { msg = AllowEventsUpdate
                            , allowEvents = model.allowEvents
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewImagesInput
                            { onInput_ = ImageOnInput
                            , addImage = AddImage
                            , removeImage = RemoveImage
                            , images = model.images
                            , imageValue = model.image
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewAllowCommandsInput
                            { msg = AllowCommandsOnClick
                            , value = model.allowCommand
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewHelp shared.velaDocsURL
                        , Components.Form.viewButton
                            { id_ = "submit"
                            , msg = SubmitForm
                            , text_ = "Add Secret"
                            , classList_ = []
                            , disabled_ = False
                            }
                        ]
                    ]
                ]
            ]
        ]
    }
