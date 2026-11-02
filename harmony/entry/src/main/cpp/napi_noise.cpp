#include "napi/native_api.h"
#include "p256_encoding.h"
#include <noise/protocol.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
using Bytes=std::vector<uint8_t>;
constexpr size_t LIMIT=256*1024, CHUNK=32768;
constexpr uint32_t MAX_RECORDS=1u<<20;
void check(bool ok,const char *message){if(!ok)throw std::runtime_error(message);}
void noise(int e){check(e==NOISE_ERROR_NONE,"Native secure operation rejected");}
int64_t now(){return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();}
struct Wipe { Bytes& value; ~Wipe(){noise_clean(value.data(),value.size());} };
struct Peer {
 NoiseHandshakeState *h=nullptr;NoiseCipherState *tx=nullptr,*rx=nullptr;
 uint32_t sent=0,received=0;bool begun=false,ready=false;
 int64_t created=now(),partialDeadline=0;Bytes partial,publicKey,hash;size_t offset=0;
 ~Peer(){if(h)noise_handshakestate_free(h);if(tx)noise_cipherstate_free(tx);if(rx)noise_cipherstate_free(rx);noise_clean(partial.data(),partial.size());}
};
struct State {uint32_t next=1;std::unordered_map<uint32_t,std::unique_ptr<Peer>> peers;};
State& state(napi_env env){void *data=nullptr;check(napi_get_instance_data(env,&data)==napi_ok&&data,"Native context unavailable");return *static_cast<State*>(data);}
std::vector<napi_value> args(napi_env env,napi_callback_info info,size_t n){std::vector<napi_value> a(n+1);size_t count=a.size();check(napi_get_cb_info(env,info,&count,a.data(),nullptr,nullptr)==napi_ok&&count==n,"Invalid native arguments");a.resize(n);return a;}
Bytes buffer(napi_env env,napi_value value){void *p=nullptr;size_t n=0;check(napi_get_arraybuffer_info(env,value,&p,&n)==napi_ok&&n<=LIMIT,"Expected bounded ArrayBuffer");if(n==0)return {};return Bytes(static_cast<uint8_t*>(p),static_cast<uint8_t*>(p)+n);}
napi_value output(napi_env env,const Bytes& b){void *p=nullptr;napi_value value;check(napi_create_arraybuffer(env,b.size(),&p,&value)==napi_ok,"Allocation failed");if(!b.empty())std::memcpy(p,b.data(),b.size());return value;}
uint32_t handle(napi_env env,napi_value value){double n=0;check(napi_get_value_double(env,value,&n)==napi_ok&&n>=1&&n<=UINT32_MAX&&std::floor(n)==n,"Invalid native handle");return static_cast<uint32_t>(n);}
Peer& peer(napi_env env,uint32_t id){auto& m=state(env).peers;auto i=m.find(id);check(i!=m.end(),"Secure session is closed");check(now()-i->second->created<=600000,"Secure session expired");return *i->second;}
napi_value failed(napi_env env,const std::exception& e,uint32_t id=0){if(id)state(env).peers.erase(id);napi_throw_error(env,nullptr,e.what());return nullptr;}
Bytes hash256(const Bytes& b){NoiseHashState *h=nullptr;noise(noise_hashstate_new_by_id(&h,NOISE_HASH_SHA256));Bytes result(32);int rc=noise_hashstate_hash_one(h,b.data(),b.size(),result.data(),result.size());noise_hashstate_free(h);noise(rc);return result;}
std::string hex(const Bytes& b){const char *digits="0123456789abcdef";std::string s;for(auto v:b){s+=digits[v>>4];s+=digits[v&15];}return s;}
void field(napi_env env,napi_value object,const char *name,const Bytes& data){check(napi_set_named_property(env,object,name,output(env,data))==napi_ok,"Object field failed");}

napi_value NewKey(napi_env env,napi_callback_info info){
 try{args(env,info,0);NoiseDHState *d=nullptr;noise(noise_dhstate_new_by_id(&d,NOISE_DH_CURVE25519));Bytes sk(32),pk(32);Wipe wipe{sk};int rc=noise_dhstate_generate_keypair(d);if(rc==NOISE_ERROR_NONE)rc=noise_dhstate_get_keypair(d,sk.data(),32,pk.data(),32);noise_dhstate_free(d);noise(rc);napi_value o;napi_create_object(env,&o);field(env,o,"publicKey",pk);field(env,o,"privateKey",sk);std::fill(sk.begin(),sk.end(),0);return o;}catch(const std::exception& e){return failed(env,e);}
}
napi_value Create(napi_env env,napi_callback_info info){
 try{auto a=args(env,info,2);auto sk=buffer(env,a[0]),pk=buffer(env,a[1]);Wipe wipe{sk};check(sk.size()==32&&pk.size()==32,"Expected 32-byte Noise keys");auto& s=state(env);check(s.peers.size()<8&&s.next<UINT32_MAX,"Native session limit");auto p=std::make_unique<Peer>();noise(noise_handshakestate_new_by_name(&p->h,"Noise_IK_25519_ChaChaPoly_BLAKE2b",NOISE_ROLE_INITIATOR));noise(noise_dhstate_set_keypair_private(noise_handshakestate_get_local_keypair_dh(p->h),sk.data(),sk.size()));std::fill(sk.begin(),sk.end(),0);noise(noise_dhstate_set_public_key(noise_handshakestate_get_remote_public_key_dh(p->h),pk.data(),pk.size()));const std::string prologue="CodexMobile/v1/Noise_IK_25519_ChaChaPoly_BLAKE2b/"+hex(hash256(pk));noise(noise_handshakestate_set_prologue(p->h,prologue.data(),prologue.size()));noise(noise_handshakestate_start(p->h));const uint32_t id=s.next++;s.peers.emplace(id,std::move(p));napi_value v;napi_create_uint32(env,id,&v);return v;}catch(const std::exception& e){return failed(env,e);}
}
napi_value Begin(napi_env env,napi_callback_info info){uint32_t id=0;try{auto a=args(env,info,1);id=handle(env,a[0]);auto& p=peer(env,id);check(!p.begun&&!p.ready,"Handshake already started");Bytes data(65535);NoiseBuffer b;noise_buffer_set_output(b,data.data(),data.size());noise(noise_handshakestate_write_message(p.h,&b,nullptr));data.resize(b.size);p.begun=true;return output(env,data);}catch(const std::exception& e){return failed(env,e,id);}}
napi_value Finish(napi_env env,napi_callback_info info){uint32_t id=0;try{auto a=args(env,info,2);id=handle(env,a[0]);auto& p=peer(env,id);check(p.begun&&!p.ready,"Handshake state mismatch");auto data=buffer(env,a[1]);check(data.size()<=65535,"Handshake too large");Bytes payload(65535);NoiseBuffer input,out;noise_buffer_set_input(input,data.data(),data.size());noise_buffer_set_output(out,payload.data(),payload.size());noise(noise_handshakestate_read_message(p.h,&input,&out));check(out.size==0,"Handshake cannot carry business data");p.hash.resize(64);p.publicKey.resize(32);noise(noise_handshakestate_get_handshake_hash(p.h,p.hash.data(),p.hash.size()));noise(noise_dhstate_get_public_key(noise_handshakestate_get_remote_public_key_dh(p.h),p.publicKey.data(),32));noise(noise_handshakestate_split(p.h,&p.tx,&p.rx));noise_handshakestate_free(p.h);p.h=nullptr;p.ready=true;napi_value o;napi_create_object(env,&o);field(env,o,"publicKey",p.publicKey);field(env,o,"hash",p.hash);return o;}catch(const std::exception& e){return failed(env,e,id);}}
void uint32be(uint8_t *p,uint32_t v){p[0]=v>>24;p[1]=v>>16;p[2]=v>>8;p[3]=v;}
uint32_t read32(const uint8_t *p){return (uint32_t(p[0])<<24)|(uint32_t(p[1])<<16)|(uint32_t(p[2])<<8)|p[3];}
napi_value Encrypt(napi_env env,napi_callback_info info){uint32_t id=0;try{auto a=args(env,info,2);id=handle(env,a[0]);auto& p=peer(env,id);check(p.ready,"Handshake incomplete");auto data=buffer(env,a[1]);Wipe wipe{data};check(!data.empty()&&data.size()<=LIMIT,"Business payload limit exceeded");napi_value result;napi_create_array(env,&result);uint32_t index=0;for(size_t off=0;off<data.size();off+=CHUNK){check(++p.sent<=MAX_RECORDS,"Reconnect required");size_t n=std::min(CHUNK,data.size()-off);Bytes raw(n+24);uint32be(raw.data(),data.size());uint32be(raw.data()+4,off);std::memcpy(raw.data()+8,data.data()+off,n);NoiseBuffer b;noise_buffer_set_inout(b,raw.data(),n+8,raw.size());noise(noise_cipherstate_encrypt(p.tx,&b));raw.resize(b.size);napi_set_element(env,result,index++,output(env,raw));}std::fill(data.begin(),data.end(),0);return result;}catch(const std::exception& e){return failed(env,e,id);}}
napi_value Decrypt(napi_env env,napi_callback_info info){uint32_t id=0;try{auto a=args(env,info,2);id=handle(env,a[0]);auto& p=peer(env,id);check(p.ready&&++p.received<=MAX_RECORDS,"Reconnect required");auto data=buffer(env,a[1]);check(data.size()>=24&&data.size()<=CHUNK+24,"Invalid record length");NoiseBuffer b;noise_buffer_set_inout(b,data.data(),data.size(),data.size());noise(noise_cipherstate_decrypt(p.rx,&b));uint32_t total=read32(data.data()),off=read32(data.data()+4);size_t count=b.size-8;check(total>0&&total<=LIMIT&&count>0,"Invalid fragment size");if(p.partial.empty()){check(off==0,"Missing first fragment");p.partial.resize(total);p.offset=0;p.partialDeadline=now()+10000;}check(p.partial.size()==total&&p.offset==off&&off+count<=total&&now()<p.partialDeadline,"Fragment order or deadline mismatch");std::memcpy(p.partial.data()+off,data.data()+8,count);p.offset+=count;std::fill(data.begin(),data.end(),0);if(p.offset<total){napi_value v;napi_get_undefined(env,&v);return v;}auto result=output(env,p.partial);noise_clean(p.partial.data(),p.partial.size());p.partial.clear();p.offset=0;return result;}catch(const std::exception& e){return failed(env,e,id);}}
napi_value Close(napi_env env,napi_callback_info info){try{auto a=args(env,info,1);state(env).peers.erase(handle(env,a[0]));napi_value v;napi_get_undefined(env,&v);return v;}catch(const std::exception& e){return failed(env,e);}}
napi_value PublicSpki(napi_env env,napi_callback_info info){try{auto a=args(env,info,1);return output(env,codex_encoding::spki(buffer(env,a[0])));}catch(const std::exception& e){return failed(env,e);}}
napi_value Signature(napi_env env,napi_callback_info info){try{auto a=args(env,info,1);return output(env,codex_encoding::p1363(buffer(env,a[0])));}catch(const std::exception& e){return failed(env,e);}}
napi_value Hash(napi_env env,napi_callback_info info){try{auto a=args(env,info,1);return output(env,hash256(buffer(env,a[0])));}catch(const std::exception& e){return failed(env,e);}}
napi_value Init(napi_env env,napi_value exports){noise(noise_init());auto *s=new State();napi_set_instance_data(env,s,[](napi_env,void *data,void*){delete static_cast<State*>(data);},nullptr);napi_property_descriptor methods[]={
 {"newKey",nullptr,NewKey,nullptr,nullptr,nullptr,napi_default,nullptr},{"create",nullptr,Create,nullptr,nullptr,nullptr,napi_default,nullptr},{"begin",nullptr,Begin,nullptr,nullptr,nullptr,napi_default,nullptr},{"finish",nullptr,Finish,nullptr,nullptr,nullptr,napi_default,nullptr},{"encrypt",nullptr,Encrypt,nullptr,nullptr,nullptr,napi_default,nullptr},{"decrypt",nullptr,Decrypt,nullptr,nullptr,nullptr,napi_default,nullptr},{"close",nullptr,Close,nullptr,nullptr,nullptr,napi_default,nullptr},{"publicSpki",nullptr,PublicSpki,nullptr,nullptr,nullptr,napi_default,nullptr},{"signatureP1363",nullptr,Signature,nullptr,nullptr,nullptr,napi_default,nullptr},{"sha256",nullptr,Hash,nullptr,nullptr,nullptr,napi_default,nullptr}};
 napi_define_properties(env,exports,sizeof(methods)/sizeof(methods[0]),methods);return exports;
}
}
static napi_module module={.nm_version=1,.nm_flags=0,.nm_filename=nullptr,.nm_register_func=Init,.nm_modname="codexnoise",.nm_priv=nullptr,.reserved={0}};
extern "C" __attribute__((constructor)) void RegisterCodexNoise(){napi_module_register(&module);}
