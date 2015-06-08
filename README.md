#SMPPP_GATEWAY
================

Gateway to manage one or more kannel servers or connections to differents apps, we need just only configure a yml file and read a differents message formats.

The daemon automatic create 3 queues for each app, example:

You create add an app to yml with the name "horoscopo" you need to specify

com.smpp_gateway.**horoscopo**.sender   => _you put a json to send SMS to terminal_
com.smpp_gateway.**horoscopo**.response => _daemon comunicate to your app what happen with you SMS sended_
com.smpp_gateway.**horoscopo**.receiver => _All SMS sended from Terminal to your App_

{"body":[{"cellphone":"0981460196","message":"Prueba","id":"1616070"}],"type":"2","expire_in":"03\/04\/2015 02:16:10"}

## Format message (put on com.smpp_gateway.[name_app].sender queue)
=================================

~~~~~~json
{
    "body":{
        "cellphone":"0981460196",
        "message":"Test of bulk", 
        "id": "123"
    },
    "type":"1", 
    "expire_in":"10/04/2014 18:20:00"
}
{
    "body":{
        "cellphone":"0981460196",
        "message":"Test of bulk", 
        "id": "123"
    },
    "type":"1"
}

{
    "body":[
        {
            "cellphone":"0981460196",
            "message":"Respondan ok este mensaje cuando reciban por favor."
            "id":"123"
        },
        {
            "cellphone":"0971222540",
            "message":"Respondan ok este mensaje cuando reciban por favor."
            "id": "124"
        }
    ],
    "type":"2",
    "expire_in": "10/04/2014 18:20:00"
}
~~~~~~

## RESPONSE DAEMON (recive on com.smpp_gateway.[name_app].response queue)
==================

### Correcto y pendiente de respuesta de la operadora

~~~~~~json
{'id': '1111', 'status':'ACK_DAEMON'}
~~~~~~

### Error en el formato

~~~~~~json
{'id': '1111', 'status':'NACK_DAEMON_BAD_FORMAT'}
~~~~~~

### Error cuando el "id" es duplicado

~~~~~~json
{'id': '1111', 'status':'NACK_DAEMON_ID_EXISTS'}
~~~~~~

### Error cuando el mensaje expiró

~~~~~~json
{'id': '1111', 'status':'NACK_DAEMON_EXPIRED'}
~~~~~~

### Error error en el proceso

~~~~~~json
{'id': '1111', 'status':'NACK_DAEMON'}
~~~~~~


## RESPONSE OPERATOR
====================

### Correcto y entregado a la persona

~~~~~~json
{'id': '1111', 'status':'ACK_SMSC'}
~~~~~~

### Error en el número
~~~~~~json
{'id': '1111', 'status':'NACK_SMSC_INVALID_NUMBER'}
~~~~~~

### Error cuando no hay saldo
~~~~~~json
{'id': '1111', 'status':'NACK_SMSC_NO_MONEY'}
~~~~~~

### Error cuando no se pudo obtener los datos del usuario
~~~~~~json
{'id': '1111', 'status':'NACK_SMSC_NO_USERDATA'}
~~~~~~

### Error generico de la operadora
~~~~~~json
{'id': '1111', 'status':'NACK_SMSC_GENERIC_ERROR'}
~~~~~~

### Cualquier error en el proceso
~~~~~~json
{'id': '1111', 'status':'NACK_SMSC'}
~~~~~~

## RECEIVE MESSAGE FROM TERMINALS

### Format
~~~~~~json
{'from': '0981460196', 'to': '20800', 'message':'Test', 'incoming_at': '2015-02-17T23:30:00.99'}
~~~~~~
