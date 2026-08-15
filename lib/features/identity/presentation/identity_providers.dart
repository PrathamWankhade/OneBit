import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/crypto/keystore/keystore_key_bridge.dart';
import 'package:onebit/core/crypto/keystore/keystore_providers.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/features/identity/data/identity_repository_impl.dart';
import 'package:onebit/features/identity/data/in_memory_trust_contact_repository.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/trust_contact_repository.dart';
import 'package:onebit/features/identity/domain/use_cases/add_trust_contact.dart';
import 'package:onebit/features/identity/domain/use_cases/build_identity_card.dart';
import 'package:onebit/features/identity/domain/use_cases/create_identity.dart';
import 'package:onebit/features/identity/domain/use_cases/decode_identity_card.dart';
import 'package:onebit/features/identity/domain/use_cases/decode_identity_transfer.dart';
import 'package:onebit/features/identity/domain/use_cases/delete_identity.dart';
import 'package:onebit/features/identity/domain/use_cases/derive_verification_code.dart';
import 'package:onebit/features/identity/domain/use_cases/encode_identity_transfer.dart';
import 'package:onebit/features/identity/domain/use_cases/export_backup.dart';
import 'package:onebit/features/identity/domain/use_cases/import_backup.dart';
import 'package:onebit/features/identity/domain/use_cases/load_identity.dart';
import 'package:onebit/features/identity/domain/use_cases/load_trust_contacts.dart';
import 'package:onebit/features/identity/domain/use_cases/remove_trust_contact.dart';
import 'package:onebit/features/identity/domain/use_cases/sign_data.dart';
import 'package:onebit/features/identity/domain/use_cases/update_profile.dart';
import 'package:onebit/features/identity/domain/use_cases/update_trust_contact.dart';
import 'package:onebit/features/identity/domain/use_cases/verify_signature.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The [KeystoreKeyBridge] provider (overridable with an in-memory fake).
final Provider<KeystoreKeyBridge> identityVaultProvider =
    Provider<KeystoreKeyBridge>((ref) {
      return ref.watch(keystoreKeyBridgeProvider);
    });

/// The identity repository backed by vault + preferences.
///
/// `SharedPreferencesAsync` needs no async bootstrap, so the whole graph is
/// synchronously constructible and trivially overridable in tests.
final Provider<IdentityRepository> identityRepositoryProvider =
    Provider<IdentityRepository>((ref) {
      return IdentityRepositoryImpl(
        vault: ref.watch(identityVaultProvider),
        prefs: SharedPreferencesAsync(),
        logger: ref.watch(appLoggerProvider),
        contacts: ref.watch(trustContactRepositoryProvider),
      );
    });

/// The trust contact repository (volatile until the persistence phase).
final Provider<TrustContactRepository> trustContactRepositoryProvider =
    Provider<TrustContactRepository>((ref) => InMemoryTrustContactRepository());

/// Use-case providers (composition root).
final Provider<LoadIdentity> loadIdentityProvider = Provider<LoadIdentity>(
  (ref) => LoadIdentity(ref.watch(identityRepositoryProvider)),
);

final Provider<CreateIdentity> createIdentityProvider =
    Provider<CreateIdentity>(
      (ref) => CreateIdentity(ref.watch(identityRepositoryProvider)),
    );

final Provider<UpdateProfile> updateProfileProvider = Provider<UpdateProfile>(
  (ref) => UpdateProfile(ref.watch(identityRepositoryProvider)),
);

final Provider<DeleteIdentity> deleteIdentityProvider =
    Provider<DeleteIdentity>(
      (ref) => DeleteIdentity(ref.watch(identityRepositoryProvider)),
    );

final Provider<SignData> signDataProvider = Provider<SignData>(
  (ref) => SignData(ref.watch(identityRepositoryProvider)),
);

final Provider<VerifySignature> verifySignatureProvider =
    Provider<VerifySignature>(
      (ref) => VerifySignature(ref.watch(identityRepositoryProvider)),
    );

final Provider<ExportBackup> exportBackupProvider = Provider<ExportBackup>(
  (ref) => ExportBackup(ref.watch(identityRepositoryProvider)),
);

final Provider<ImportBackup> importBackupProvider = Provider<ImportBackup>(
  (ref) => ImportBackup(ref.watch(identityRepositoryProvider)),
);

final Provider<BuildIdentityCard> buildIdentityCardProvider =
    Provider<BuildIdentityCard>(
      (ref) => BuildIdentityCard(ref.watch(identityRepositoryProvider)),
    );

final Provider<DecodeIdentityCard> decodeIdentityCardProvider =
    Provider<DecodeIdentityCard>((ref) => const DecodeIdentityCard());

final Provider<EncodeIdentityTransfer> encodeIdentityTransferProvider =
    Provider<EncodeIdentityTransfer>(
      (ref) => EncodeIdentityTransfer(ref.watch(identityRepositoryProvider)),
    );

final Provider<DecodeIdentityTransfer> decodeIdentityTransferProvider =
    Provider<DecodeIdentityTransfer>(
      (ref) => DecodeIdentityTransfer(ref.watch(identityRepositoryProvider)),
    );

final Provider<DeriveVerificationCode> deriveVerificationCodeProvider =
    Provider<DeriveVerificationCode>(
      (ref) => DeriveVerificationCode(ref.watch(identityRepositoryProvider)),
    );

final Provider<LoadTrustContacts> loadTrustContactsProvider =
    Provider<LoadTrustContacts>(
      (ref) => LoadTrustContacts(ref.watch(trustContactRepositoryProvider)),
    );

final Provider<AddTrustContact> addTrustContactProvider =
    Provider<AddTrustContact>(
      (ref) => AddTrustContact(ref.watch(trustContactRepositoryProvider)),
    );

final Provider<UpdateTrustContact> updateTrustContactProvider =
    Provider<UpdateTrustContact>(
      (ref) => UpdateTrustContact(ref.watch(trustContactRepositoryProvider)),
    );

final Provider<RemoveTrustContact> removeTrustContactProvider =
    Provider<RemoveTrustContact>(
      (ref) => RemoveTrustContact(ref.watch(trustContactRepositoryProvider)),
    );
