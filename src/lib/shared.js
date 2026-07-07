import {supabase} from './supabase'

const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms))
const isNetworkError=error=>/failed to fetch|network|fetch/i.test(String(error?.message||error||''))
async function retryNetwork(operation){
 let lastError
 for(let attempt=0;attempt<3;attempt++){
  try{return await operation()}
  catch(error){lastError=error;if(!isNetworkError(error)||attempt===2)throw error;await wait(500*(attempt+1))}
 }
 throw lastError
}

export async function loadWorkspace(userId){
 const [{data:profile,error:profileError},{data:offices,error:officeError},{data:profiles,error:peopleError},{data:memberships,error:membershipError},{data:tasks,error:taskError},{data:notifications,error:noticeError}]=await retryNetwork(()=>Promise.all([
  supabase.from('profiles').select('*').eq('id',userId).single(),supabase.from('offices').select('*').eq('active',true).order('name'),supabase.from('profiles').select('*').eq('active',true).order('full_name'),supabase.from('office_memberships').select('*'),supabase.from('tasks').select('*').order('created_at',{ascending:false}),supabase.from('notifications').select('*').is('read_at',null).order('created_at',{ascending:false})
 ]))
 const error=profileError||officeError||peopleError||membershipError||taskError||noticeError;if(error)throw error
 const officeMap=Object.fromEntries(offices.map(o=>[o.id,o.name])),personMap=Object.fromEntries(profiles.map(p=>[p.id,p.full_name]))
 return {profile,offices:offices.map(o=>({id:o.id,name:o.name,location:'',provider:''})),employees:profiles.map(p=>({id:p.id,name:p.full_name,initials:p.full_name.split(' ').map(x=>x[0]).join('').slice(0,2).toUpperCase(),role:p.position,accessRole:p.role,email:p.email,completed:0,capacity:20,active:p.active})),notifications,tasks:tasks.map(t=>({dbId:t.id,id:t.external_id||t.id,patient:t.patient_name,office:officeMap[t.office_id]||'Unknown office',officeId:t.office_id,type:t.task_type,employee:personMap[t.assigned_to]||'Unassigned',employeeId:t.assigned_to,priority:t.priority,status:t.status,due:t.due_at?.slice(0,10)||'',dos:t.date_of_service||'',followup:t.last_follow_up_at?.slice(0,10)||'—',next:t.next_action_at?.slice(0,10)||'',completion:t.completed_at?.slice(0,10)||'—',notes:t.notes||'',postedAmount:t.posted_amount||'',postedDate:t.posted_date||'',qaStatus:t.qa_status,qaScore:t.qa_score||'',qaNotes:t.qa_notes||'',qaReviewer:t.qa_reviewer}))}
}

export async function upsertTasks(tasks,userId,offices,employees){
 const officeId=name=>offices.find(o=>o.name===name)?.id,employeeId=name=>employees.find(e=>e.name===name)?.id
 const rows=tasks.filter(t=>officeId(t.office)).map(t=>({external_id:t.id,office_id:officeId(t.office),patient_reference:t.id,patient_name:t.patient,date_of_service:/^\d{4}-\d{2}-\d{2}$/.test(t.dos)?t.dos:null,task_type:t.type,assigned_to:employeeId(t.employee)||null,priority:String(t.priority||'medium').toLowerCase(),status:t.status,due_at:t.due&&/^\d{4}-\d{2}-\d{2}$/.test(t.due)?new Date(t.due+'T12:00:00Z').toISOString():null,notes:t.notes||null,last_follow_up_at:null,next_action_at:t.next&&/^\d{4}-/.test(t.next)?new Date(t.next+'T12:00:00Z').toISOString():null,completed_at:t.completion&&/^\d{4}-/.test(t.completion)?new Date(t.completion+'T12:00:00Z').toISOString():null,created_by:userId,posted_amount:t.postedAmount===''?null:Number(t.postedAmount),posted_date:t.postedDate||null,qa_status:t.qaStatus||'Pending review',qa_score:t.qaScore===''?null:Number(t.qaScore),qa_notes:t.qaNotes||null,qa_reviewer:t.qaReviewer&&/^[0-9a-f-]{36}$/i.test(t.qaReviewer)?t.qaReviewer:null}))
 if(!rows.length)throw new Error('No tasks matched an active office')
 const {error}=await retryNetwork(()=>supabase.from('tasks').upsert(rows,{onConflict:'external_id'}));if(error)throw error
}

export async function deleteTask(task){const externalId=task?.id||task?.external_id;if(!externalId)throw new Error('Missing task id');const {error}=await retryNetwork(()=>supabase.from('tasks').delete().eq('external_id',externalId));if(error)throw error}
export async function updateProfile(id,changes){const {error}=await supabase.from('profiles').update(changes).eq('id',id);if(error)throw error}
export async function deactivateProfile(id){const {error:memberError}=await supabase.from('office_memberships').delete().eq('user_id',id);if(memberError)throw memberError;const {error}=await supabase.from('profiles').update({active:false}).eq('id',id);if(error)throw error}
export async function saveOffices(offices){
 const codeFor=o=>String(o.code||o.name||'office').toUpperCase().replace(/[^A-Z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,18)||'OFFICE'
 for(const office of offices){
  if(/^[0-9a-f-]{36}$/i.test(office.id)){
   const {error}=await supabase.from('offices').update({name:office.name,code:codeFor(office),active:office.active!==false}).eq('id',office.id)
   if(error)throw error
  }else{
   const {error}=await supabase.from('offices').insert({name:office.name,code:codeFor(office),active:office.active!==false})
   if(error)throw error
  }
 }
}
export async function setEmployeeOffices(userId,officeIds){const {error:removeError}=await supabase.from('office_memberships').delete().eq('user_id',userId);if(removeError)throw removeError;if(officeIds.length){const {error}=await supabase.from('office_memberships').insert(officeIds.map(office_id=>({office_id,user_id:userId})));if(error)throw error}}
export async function sendEmployeeAccess(email,fullName){const {error}=await supabase.auth.signInWithOtp({email,options:{shouldCreateUser:true,emailRedirectTo:window.location.origin+'?setup=password',data:{full_name:fullName,requires_password_setup:true}}});if(error)throw error}
export async function markNotificationsRead(ids){const dbIds=ids.filter(id=>/^[0-9a-f-]{36}$/i.test(id));if(!dbIds.length)return;await supabase.from('notifications').update({read_at:new Date().toISOString()}).in('id',dbIds)}
