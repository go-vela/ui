{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add exposing (Model, Msg, page, view)

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
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (defaultSecretPayload)
import View exposing (View)


{-| page : takes user, shared model, route, and returns an org's team shared secrets add secret page.
-}
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


{-| toLayout : takes user, route, model, and passes an org's team shared secrets add secret page info to Layouts.
-}
toLayout : Auth.User -> Route { engine : String, org : String, team : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "Add Shared Secret Help"
              , content = "vela add secret -h"
              , docs = Just "secret/add"
              }
            , { name = "Add Shared Secret Example"
              , content =
                    "vela add secret --secret.engine native --secret.type shared --org "
                        ++ route.params.org
                        ++ " --team octokitties --name foo --value bar --event push"
              , docs = Just "secret/add"
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for an org's team shared secrets add secret page.
-}
type alias Model =
    { form : Components.SecretForm.Form
    }


{-| init : takes in a shared model, route, and returns a model and effect.
-}
init : Shared.Model -> Route { engine : String, org : String, team : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { form = Components.SecretForm.defaultSharedSecretForm route.params.team }
    , Effect.none
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = -- SECRETS
      AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | TeamOnInput String
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | AddImage String
    | RemoveImage String
    | OrgOnInput String
    | RepoOnInput String
    | AddRepo String
    | RemoveRepo String
    | AllowCommandsOnClick String
    | AllowSubstitutionOnClick String
    | AllowEventsUpdate { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } Bool
    | SubmitForm


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { engine : String, org : String, team : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    let
        form =
            model.form
    in
    case msg of
        -- SECRETS
        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( { form = Components.SecretForm.defaultSharedSecretForm route.params.team }
                    , Effect.addAlertSuccess
                        { content = "Added shared secret '" ++ secret.name ++ "'."
                        , addToastIfUnique = True
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        TeamOnInput val ->
            ( { model | form = { form | team = val } }
            , Effect.none
            )

        NameOnInput val ->
            ( { model | form = { form | name = val } }
            , Effect.none
            )

        ValueOnInput val ->
            ( { model | form = { form | value = val } }
            , Effect.none
            )

        ImageOnInput val ->
            ( { model | form = { form | image = val } }
            , Effect.none
            )

        AddImage image ->
            ( { model
                | form =
                    { form
                        | images =
                            form.images
                                |> List.append [ image ]
                                |> List.Extra.unique
                        , image = ""
                    }
              }
            , Effect.none
            )

        RemoveImage image ->
            ( { model
                | form =
                    { form
                        | images =
                            form.images
                                |> List.filter ((/=) image)
                    }
              }
            , Effect.none
            )

        OrgOnInput val ->
            ( { model | form = { form | org = val } }
            , Effect.none
            )

        RepoOnInput val ->
            ( { model | form = { form | repo = val } }
            , Effect.none
            )

        AddRepo repo ->
            ( { model
                | form =
                    { form
                        | repoAllowlist =
                            form.repoAllowlist
                                |> List.append [ repo ]
                                |> List.Extra.unique
                        , org = ""
                        , repo = ""
                    }
              }
            , Effect.none
            )

        RemoveRepo repo ->
            ( { model
                | form =
                    { form
                        | repoAllowlist =
                            form.repoAllowlist
                                |> List.filter ((/=) repo)
                    }
              }
            , Effect.none
            )

        AllowCommandsOnClick val ->
            ( { model
                | form =
                    { form
                        | allowCommand = Util.yesNoToBool val
                    }
              }
            , Effect.none
            )

        AllowSubstitutionOnClick val ->
            ( { model
                | form =
                    { form
                        | allowSubstitution = Util.yesNoToBool val
                    }
              }
            , Effect.none
            )

        AllowEventsUpdate options val ->
            ( { model
                | form =
                    Vela.setAllowEvents model.form options.event val
              }
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultSecretPayload
                        | type_ = Just Vela.SharedSecret
                        , org = Just route.params.org
                        , repo = Nothing
                        , team = Just form.team
                        , name = Util.stringToMaybe form.name
                        , value = Util.stringToMaybe form.value
                        , allowEvents = Just form.allowEvents
                        , images = Just form.images
                        , allowCommand = Just form.allowCommand
                        , allowSubstitution = Just form.allowSubstitution
                        , repoAllowlist = Just form.repoAllowlist
                    }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.addSharedSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = AddSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , team = form.team
                , body = body
                }
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for an org's team shared secrets add secret page.
-}
view : Shared.Model -> Route { engine : String, org : String, team : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.team, Nothing )
            , ( "Shared Secrets", Just <| Route.Path.Dash_Secrets_Engine__Shared_Org__Team_ { engine = route.params.engine, org = route.params.org, team = route.params.team } )
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
                    [ h2 [] [ text <| String.Extra.toTitleCase "add shared secret" ]
                    , div [ class "secret-form" ]
                        [ Components.Form.viewInputSection
                            { title = Just "Team"
                            , subtitle = Nothing
                            , id_ = "team"
                            , val = model.form.team
                            , placeholder_ = "GitHub Team"
                            , classList_ = [ ( "secret-team", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = TeamOnInput
                            , disabled_ = False
                            , min = Nothing
                            , max = Nothing
                            , required = False
                            }
                        , Components.Form.viewInputSection
                            { title = Just "Name"
                            , subtitle = Nothing
                            , id_ = "name"
                            , val = model.form.name
                            , placeholder_ = "Secret Name"
                            , classList_ = [ ( "secret-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = NameOnInput
                            , disabled_ = False
                            , min = Nothing
                            , max = Nothing
                            , required = False
                            }
                        , Components.Form.viewTextareaSection
                            { title = Just "Value"
                            , subtitle = Nothing
                            , id_ = "value"
                            , val = model.form.value
                            , placeholder_ = "Secret Value"
                            , classList_ = [ ( "secret-value", True ) ]
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = ValueOnInput
                            , disabled_ = False
                            , focusOutFunc = Nothing
                            }
                        , Components.SecretForm.viewAllowEventsSelect
                            shared
                            { msg = AllowEventsUpdate
                            , allowEvents = model.form.allowEvents
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewImagesInput
                            { onInput_ = ImageOnInput
                            , addImage = AddImage
                            , removeImage = RemoveImage
                            , images = model.form.images
                            , imageValue = model.form.image
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewRepoAllowlistInput
                            { onOrgInput_ = OrgOnInput
                            , onRepoInput_ = RepoOnInput
                            , addRepo = AddRepo
                            , removeRepo = RemoveRepo
                            , repos = model.form.repoAllowlist
                            , orgValue = model.form.org
                            , repoValue = model.form.repo
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewAllowCommandsInput
                            { msg = AllowCommandsOnClick
                            , value = model.form.allowCommand
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewAllowSubstitutionInput
                            { msg = AllowSubstitutionOnClick
                            , value = model.form.allowSubstitution
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
