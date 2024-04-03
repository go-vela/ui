{--
SPDX-License-Identifier: Apache-2.0
--}


module Auth.Jwt exposing
    ( JwtAccessToken
    , JwtAccessTokenClaims
    , decodeJwtAccessToken
    , extractJwtClaims
    )

import Json.Decode as Decode exposing (Decoder, bool, field, int, string)
import Json.Decode.Pipeline exposing (required)
import Time
import Utils.Helpers as Util


{-| JwtAccessToken : alias for a string representing the access token.
-}
type alias JwtAccessToken =
    String


{-| decodeJwtAccessToken : decodes the access token.
-}
decodeJwtAccessToken : Decoder JwtAccessToken
decodeJwtAccessToken =
    field "token" string


{-| JwtAccessTokenClaims : defines the shape of the access token claims.
-}
type alias JwtAccessTokenClaims =
    { is_admin : Bool
    , is_active : Bool
    , exp : Time.Posix
    , iat : Time.Posix
    , sub : String
    }


{-| decodeJwtAccessTokenClaims : the decoder to validate type for required the access token claims.
-}
decodeJwtAccessTokenClaims : Decoder JwtAccessTokenClaims
decodeJwtAccessTokenClaims =
    Decode.succeed JwtAccessTokenClaims
        |> required "is_admin" bool
        |> required "is_active" bool
        |> required "exp" posixFromInt
        |> required "iat" posixFromInt
        |> required "sub" string


{-| defaultJwtAccessTokenClaims : the default claims for the access token.
-}
defaultJwtAccessTokenClaims : JwtAccessTokenClaims
defaultJwtAccessTokenClaims =
    JwtAccessTokenClaims False False (Time.millisToPosix 0) (Time.millisToPosix 0) ""


{-| posixFromInt : converts the incoming time (formatted as epoch in seconds)
to Elm's Time.Posix format.
-}
posixFromInt : Decoder Time.Posix
posixFromInt =
    int |> Decode.map (\time -> Time.millisToPosix <| time * 1000)


{-| extractJwtClaims : attempts to extract the token claims from the access token.
-}
extractJwtClaims : JwtAccessToken -> JwtAccessTokenClaims
extractJwtClaims token =
    let
        jwtParts : List String
        jwtParts =
            String.split "." token

        jwtPayload : String
        jwtPayload =
            case jwtParts of
                _ :: payload :: _ ->
                    Util.base64Decode payload

                _ ->
                    ""
    in
    case Decode.decodeString decodeJwtAccessTokenClaims jwtPayload of
        Ok p ->
            p

        Err _ ->
            defaultJwtAccessTokenClaims
