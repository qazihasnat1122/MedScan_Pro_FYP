import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PublicFooter extends StatelessWidget {
  const PublicFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    Widget brandBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2023),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF2DD4BF), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('MedScan ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              const Text('Pro', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'AI-Powered Medicine Verification & Counterfeit Detection System. Supporting safer medicine access through verified references.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.6, fontSize: 13),
        ),
      ],
    );

    Widget exploreBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EXPLORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        _buildFooterLink(context, 'Home', '/'),
        _buildFooterLink(context, 'Medicine Directory', '/medicines'),
        _buildFooterLink(context, 'Safety Alerts', '/alerts'),
        _buildFooterLink(context, 'How Verification Works', '/how-it-works'),
        _buildFooterLink(context, 'About the Platform', '/about'),
        _buildFooterLink(context, 'App Images & Assets Gallery', '/assets', textColor: const Color(0xFF2DD4BF)),
      ],
    );

    Widget orgBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ORGANIZATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        _buildFooterLink(context, 'Manufacturer Portal', '/login?intent=manufacturer'),
        _buildFooterLink(context, 'DRAP Regulatory Admin', '/login?intent=admin'),
        _buildFooterLink(context, 'Packaging Reference API (Gov / B2B)', '#'),
        _buildFooterLink(context, 'Serialization Guidelines', '#'),
      ],
    );

    Widget regulatoryBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REGULATORY CONTEXT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        const Text(
          'MedScan Pro is a technological and academic prototype for medicine verification. Reference data is cross-checked against registered formulations. Verification results indicate reference match and do not replace physical chemical assay testing.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.6, fontSize: 13),
        ),
      ],
    );

    return Column(
      children: [
        Container(
          height: isMobile ? 220 : 300,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/assembly_line.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            color: const Color(0xFF071214).withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ensuring Supply Chain Integrity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connecting manufacturers, pharmacies, and patients.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: isMobile ? 15 : 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isMobile ? 40 : 80,
          ),
          color: const Color(0xFF040A0B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 60), child: brandBlock)),
                    Expanded(flex: 2, child: exploreBlock),
                    Expanded(flex: 2, child: orgBlock),
                    Expanded(flex: 3, child: regulatoryBlock),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brandBlock,
                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFF16373A)),
                    const SizedBox(height: 24),
                    exploreBlock,
                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFF16373A)),
                    const SizedBox(height: 24),
                    orgBlock,
                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFF16373A)),
                    const SizedBox(height: 24),
                    regulatoryBlock,
                  ],
                ),
              SizedBox(height: isMobile ? 36 : 60),
              const Divider(color: Color(0xFF16373A)),
              const SizedBox(height: 24),
              if (!isMobile)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('© 2026 MedScan Pro. Developed for Pakistan Medicine Safety.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    Row(
                      children: [
                        _buildBottomLink('Privacy Policy'),
                        const SizedBox(width: 24),
                        _buildBottomLink('Terms of Service'),
                        const SizedBox(width: 24),
                        _buildBottomLink('Disclaimer'),
                      ],
                    )
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _buildBottomLink('Privacy Policy'),
                        _buildBottomLink('Terms of Service'),
                        _buildBottomLink('Disclaimer'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('© 2026 MedScan Pro. Developed for Pakistan Medicine Safety.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLink(BuildContext context, String title, String route, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          if (route != '#') context.go(route);
        },
        hoverColor: Colors.transparent,
        child: Text(title, style: TextStyle(color: textColor ?? const Color(0xFF94A3B8), fontSize: 14)),
      ),
    );
  }

  Widget _buildBottomLink(String title) {
    return InkWell(
      onTap: () {},
      hoverColor: Colors.transparent,
      child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
    );
  }
}
