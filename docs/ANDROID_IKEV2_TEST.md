# VPN IKEv2 de teste no Android

O APK de debug pode criar e conectar o perfil IKEv2/IPsec PSK automaticamente.
As credenciais **não** ficam no Git. Antes de compilar, acrescente ao arquivo
`android/local.properties`:

```properties
CAMI_VPN_SERVER=SEU_SERVIDOR_IKEV2
CAMI_VPN_REMOTE_ID=SEU_IDENTIFICADOR_IPSEC
CAMI_VPN_PSK=COLE_A_CHAVE_PRE_COMPARTILHADA_AQUI
```

Gere um novo APK depois de salvar o arquivo. Os valores são embutidos no APK de
debug, portanto ele não deve ser distribuído. Troque a PSK depois do teste.

Na primeira abertura, o Android exibe a confirmação obrigatória para o CAMI
configurar uma VPN. Depois da autorização, o app reconecta o perfil nas próximas
aberturas. Esta integração requer Android 11 ou superior e um servidor
IKEv2/IPsec PSK com acesso à rede privada onde o Frigate está instalado.

O CAMI desliga a VPN quando vai para segundo plano ou é fechado. Ela também pode
ser encerrada em **Ajustes > Desconectar VPN**; o logout desliga a conexão.
