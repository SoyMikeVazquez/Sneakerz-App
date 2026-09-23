import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sneakerz_app/models/cart_item_model.dart';

class EmailService {
  /// Envía un correo con la confirmación de la orden usando la API de Resend
  static Future<bool> sendOrderNotification({
    required String orderId,
    required String userEmail,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    required double total,
    required bool isDelivery,
    String? deliveryAddress,
    String? branchName,
    double? shippingCost,
  }) async {
    final apiKey = dotenv.env['RESEND_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('EmailService: RESEND_API_KEY no configurada. Omitiendo envío de correo.');
      return false;
    }

    try {
      final itemsHtml = items.map((item) => '''
        <tr>
          <td style="padding: 8px; border-bottom: 1px solid #e5e7eb;">${item.name} x${item.quantity}</td>
          <td style="padding: 8px; border-bottom: 1px solid #e5e7eb; text-align: right; font-weight: bold;">\$${(item.price * item.quantity).toStringAsFixed(2)} MXN</td>
        </tr>
      ''').join();

      String deliveryHtml = '';
      if (isDelivery) {
        deliveryHtml = '''
          <div style="background-color: #f3f4f6; border-radius: 8px; padding: 12px; margin-top: 16px;">
            <p style="margin: 0; font-size: 14px; font-weight: bold; color: #111827;">🚚 Envío a Domicilio</p>
            <p style="margin: 4px 0 0; font-size: 13px; color: #4b5563;"><strong>Sucursal:</strong> ${branchName ?? 'Sucursal Sneakerz'}</p>
            <p style="margin: 4px 0 0; font-size: 13px; color: #4b5563;"><strong>Dirección de entrega:</strong> ${deliveryAddress ?? 'No especificada'}</p>
            <p style="margin: 4px 0 0; font-size: 13px; color: #4b5563;"><strong>Costo de envío:</strong> \$${(shippingCost ?? 0.0).toStringAsFixed(2)} MXN</p>
          </div>
        ''';
      }

      final htmlBody = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb; margin: 0; padding: 20px; }
          .container { max-width: 580px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; padding: 28px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05); }
          .header { text-align: center; border-bottom: 2px solid #f3f4f6; padding-bottom: 18px; margin-bottom: 20px; }
          .title { font-size: 24px; font-weight: 900; color: #111827; margin: 0; }
          .order-id { font-size: 13px; color: #6b7280; margin-top: 6px; }
          .table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 14px; }
          .totals { margin-top: 20px; border-top: 2px dashed #e5e7eb; padding-top: 14px; }
          .total-row { display: flex; justify-content: space-between; font-size: 14px; margin-bottom: 6px; }
          .grand-total { font-size: 18px; font-weight: 900; color: #111827; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 class="title">SNEAKERZ</h1>
            <p class="order-id">Confirmación de Pedido #${orderId.substring(0, 8)}</p>
          </div>
          <p style="font-size: 15px; color: #374151;">¡Hola! Hemos recibido tu orden con éxito y está siendo procesada.</p>
          
          <table class="table">
            <thead>
              <tr style="background-color: #f9fafb; color: #6b7280; font-size: 12px; text-transform: uppercase;">
                <th style="padding: 8px; text-align: left;">Producto / Servicio</th>
                <th style="padding: 8px; text-align: right;">Precio</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>

          $deliveryHtml

          <div class="totals">
            <table style="width: 100%; font-size: 14px;">
              <tr>
                <td style="color: #6b7280; padding: 4px 0;">Subtotal:</td>
                <td style="text-align: right; font-weight: 600;">\$${subtotal.toStringAsFixed(2)} MXN</td>
              </tr>
              ${discount > 0 ? '''
              <tr>
                <td style="color: #10b981; padding: 4px 0;">Descuento:</td>
                <td style="text-align: right; color: #10b981; font-weight: 600;">-\$${discount.toStringAsFixed(2)} MXN</td>
              </tr>
              ''' : ''}
              ${isDelivery ? '''
              <tr>
                <td style="color: #6b7280; padding: 4px 0;">Envío:</td>
                <td style="text-align: right; font-weight: 600;">\$${(shippingCost ?? 0.0).toStringAsFixed(2)} MXN</td>
              </tr>
              ''' : ''}
              <tr style="border-top: 1px solid #e5e7eb;">
                <td style="font-size: 18px; font-weight: 900; padding: 8px 0; color: #111827;">Total:</td>
                <td style="font-size: 18px; font-weight: 900; text-align: right; padding: 8px 0; color: #111827;">\$${total.toStringAsFixed(2)} MXN</td>
              </tr>
            </table>
          </div>

          <p style="margin-top: 30px; font-size: 13px; color: #9ca3af; text-align: center;">
            Gracias por confiar en Sneakerz. Si tienes alguna duda contáctanos.
          </p>
        </div>
      </body>
      </html>
      ''';

      final url = Uri.parse('https://api.resend.com/emails');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'from': 'Sneakerz <onboarding@resend.dev>',
          // En pruebas sin dominio verificado, Resend solo permite enviar al correo de la cuenta
          'to': [userEmail.isNotEmpty ? userEmail : 'delivered@resend.dev'],
          'subject': 'Confirmación de Pedido - Sneakerz #${orderId.substring(0, 8)}',
          'html': htmlBody,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('EmailService: Correo enviado con éxito mediante Resend');
        return true;
      } else {
        debugPrint('EmailService: Error de Resend (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('EmailService: Excepción enviando correo: $e');
      return false;
    }
  }

  /// Envía un correo notificando que la compra fue aprobada y que el equipo se contactará para coordinar el envío/entrega
  static Future<bool> sendOrderApprovedNotification({
    required String orderId,
    required String userEmail,
    String? customerName,
    String? customerPhone,
    required double total,
    required bool isDelivery,
    String? deliveryAddress,
    String? branchName,
    List<dynamic>? items,
  }) async {
    final apiKey = dotenv.env['RESEND_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('EmailService: RESEND_API_KEY no configurada. Omitiendo envío de correo de aprobación.');
      return false;
    }

    try {
      final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
      final clientName = (customerName != null && customerName.trim().isNotEmpty) ? customerName.trim() : 'Cliente';

      String itemsSummaryHtml = '';
      if (items != null && items.isNotEmpty) {
        final rows = items.map((item) {
          final name = item['name'] ?? item['item_id'] ?? 'Producto / Servicio';
          final qty = item['quantity'] ?? 1;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          return '''
            <tr>
              <td style="padding: 10px 8px; border-bottom: 1px solid #e5e7eb; color: #374151;">$name <span style="color: #6b7280; font-size: 12px;">x$qty</span></td>
              <td style="padding: 10px 8px; border-bottom: 1px solid #e5e7eb; text-align: right; font-weight: 700; color: #111827;">\$${(price * qty).toStringAsFixed(2)} MXN</td>
            </tr>
          ''';
        }).join();

        itemsSummaryHtml = '''
          <div style="margin-top: 24px;">
            <p style="font-size: 13px; font-weight: 700; text-transform: uppercase; color: #6b7280; margin-bottom: 8px; letter-spacing: 0.5px;">Detalle del Pedido</p>
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
              <tbody>
                $rows
              </tbody>
            </table>
          </div>
        ''';
      }

      String deliveryInfoHtml = '';
      if (isDelivery) {
        deliveryInfoHtml = '''
          <div style="background-color: #eff6ff; border: 1px solid #bfdbfe; border-radius: 12px; padding: 16px; margin-top: 20px;">
            <p style="margin: 0 0 6px 0; font-size: 14px; font-weight: 800; color: #1d4ed8;">🚚 Envío a Domicilio Programado</p>
            ${deliveryAddress != null && deliveryAddress.isNotEmpty ? '<p style="margin: 4px 0 0; font-size: 13px; color: #1e3a8a;"><strong>Dirección de destino:</strong> $deliveryAddress</p>' : ''}
            ${branchName != null && branchName.isNotEmpty ? '<p style="margin: 4px 0 0; font-size: 13px; color: #1e3a8a;"><strong>Sucursal de despacho:</strong> $branchName</p>' : ''}
          </div>
        ''';
      } else {
        deliveryInfoHtml = '''
          <div style="background-color: #f3f4f6; border: 1px solid #e5e7eb; border-radius: 12px; padding: 16px; margin-top: 20px;">
            <p style="margin: 0 0 6px 0; font-size: 14px; font-weight: 800; color: #111827;">🏪 Retiro en Sucursal</p>
            ${branchName != null && branchName.isNotEmpty ? '<p style="margin: 4px 0 0; font-size: 13px; color: #4b5563;"><strong>Sucursal:</strong> $branchName</p>' : ''}
          </div>
        ''';
      }

      final contactInfo = (customerPhone != null && customerPhone.trim().isNotEmpty)
          ? 'al teléfono <strong>${customerPhone.trim()}</strong> o vía este correo'
          : 'a través de este correo electrónico';

      final htmlBody = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb; margin: 0; padding: 20px; color: #111827; }
          .container { max-width: 580px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; padding: 32px; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.06); }
          .badge { display: inline-block; background-color: #d1fae5; color: #065f46; font-size: 12px; font-weight: 800; padding: 5px 14px; border-radius: 20px; text-transform: uppercase; letter-spacing: 0.5px; }
          .header { text-align: center; border-bottom: 2px solid #f3f4f6; padding-bottom: 22px; margin-bottom: 24px; }
          .title { font-size: 26px; font-weight: 900; color: #111827; margin: 8px 0 4px 0; }
          .order-id { font-size: 14px; color: #6b7280; margin: 0; }
          .action-card { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #ffffff; border-radius: 12px; padding: 22px; margin: 20px 0; text-align: center; box-shadow: 0 4px 10px rgba(16, 185, 129, 0.25); }
          .action-card h2 { margin: 0 0 6px 0; font-size: 20px; font-weight: 900; }
          .action-card p { margin: 0; font-size: 14px; opacity: 0.95; line-height: 1.5; }
          .info-box { background-color: #f8fafc; border-left: 4px solid #10b981; padding: 14px 16px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .totals { margin-top: 24px; border-top: 2px dashed #e5e7eb; padding-top: 16px; }
          .footer { margin-top: 32px; border-top: 1px solid #f3f4f6; padding-top: 20px; text-align: center; font-size: 13px; color: #9ca3af; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <span class="badge">Aprobado y Confirmado</span>
            <h1 class="title">SNEAKERZ</h1>
            <p class="order-id">Orden #$shortId</p>
          </div>

          <div class="action-card">
            <h2>¡Tu compra ha sido aprobada! 🎉</h2>
            <p>Hemos procesado y aprobado tu compra exitosamente.</p>
          </div>

          <p style="font-size: 15px; line-height: 1.6; color: #374151;">
            Hola <strong>$clientName</strong>,
          </p>
          <p style="font-size: 15px; line-height: 1.6; color: #374151;">
            Queremos confirmarte que tu pedido <strong>#$shortId</strong> fue marcado como <strong>aprobado y completado</strong> en nuestro sistema.
          </p>

          <div class="info-box">
            <p style="margin: 0; font-size: 14px; color: #1e293b; line-height: 1.5;">
              📦 <strong>Coordinación de Entrega:</strong><br>
              Nuestro equipo de Sneakerz se pondrá en contacto contigo $contactInfo para coordinar el envío y despacho de tus productos.
            </p>
          </div>

          $deliveryInfoHtml

          $itemsSummaryHtml

          <div class="totals">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span style="font-size: 16px; font-weight: 800; color: #111827;">Total Pagado:</span>
              <span style="font-size: 18px; font-weight: 900; color: #10b981;">\$${total.toStringAsFixed(2)} MXN</span>
            </div>
          </div>

          <div class="footer">
            <p style="margin: 0 0 6px 0; font-weight: 600; color: #4b5563;">¡Gracias por comprar en Sneakerz!</p>
            <p style="margin: 0;">Si tienes alguna consulta, puedes responder a este correo.</p>
          </div>
        </div>
      </body>
      </html>
      ''';

      final url = Uri.parse('https://api.resend.com/emails');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'from': 'Sneakerz <onboarding@resend.dev>',
          'to': [userEmail.isNotEmpty ? userEmail : 'delivered@resend.dev'],
          'subject': '¡Tu compra ha sido aprobada! - Sneakerz #$shortId',
          'html': htmlBody,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('EmailService: Correo de aprobación enviado con éxito a $userEmail');
        return true;
      } else {
        debugPrint('EmailService: Error enviando correo de aprobación (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('EmailService: Excepción enviando correo de aprobación: $e');
      return false;
    }
  }
}

