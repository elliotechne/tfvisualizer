kubectl exec tfvisualizer-app-578dffb464-47w9d -n tfvisualizer -- python3 -c "                                                                         
from app.main import create_app                                                                                                                        
app = create_app()                                                                                                                                     
print('Available routes:')                                                                                                                             
for rule in sorted(app.url_map.iter_rules(), key=lambda r: r.rule):                                                                                   
  methods = ','.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))                                                                                     
  print(f'{rule.rule:50s} [{methods}]')
